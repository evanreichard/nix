# llama-swap — Manual Testing

How to exercise a backend by hand, without redeploying the host or restarting the
`llama-swap` service. Everything below runs on port **8081** so it never collides with
llama-swap on 8080.

## NInfer (Qwen3.8-27B)

### 1. Build the engine

```bash
nix build /etc/nixos#ninfer-3090
./result/bin/ninfer-serve --help
```

Full compile is ~45 minutes of CUDA. If the desktop already deployed the llama-swap
config, the store path is present and this is instant.

### 2. Fetch the artifact

```bash
/etc/nixos/modules/nixos/services/llama-swap/setup-qwen38-ninfer.sh
```

Downloads ~17 GiB to `/mnt/ssd/Ninfer/Models/qwen3_8_27b.ninfer`, resumable and
idempotent. Add `NINFER_VERIFY_SHA=1` to checksum afterwards, or
`NINFER_MODEL_DIR=/some/other/dir` to stage a test copy elsewhere.

### 3. Run it directly

Bind `0.0.0.0` and pick a `--model-id` — NInfer rejects any request whose `model` field
does not match it.

```bash
CUDA_VISIBLE_DEVICES=0 CUDA_DEVICE_ORDER=PCI_BUS_ID \
./result/bin/ninfer-serve /mnt/ssd/Ninfer/Models/qwen3_8_27b.ninfer \
  --host 0.0.0.0 --port 8081 \
  --model-id qwen3.8-27b \
  --max-context 65536 --kv-capacity 65536 \
  --max-concurrency 1 --max-pending-requests 16 \
  --prefill-chunk 1024 --kv-dtype int8 \
  --spec mtp --draft-tokens 3 --lm-head-draft \
  --preserve-thinking --cors
```

Swap the profile block to match the config under test:

| Profile | Flags |
| --- | --- |
| C1 / 173K | `--max-context 177152 --kv-capacity 177152 --max-concurrency 1 --max-pending-requests 16 --prefill-chunk 1024` |
| C1 / 229K rk8v4 | `--max-context 234496 --kv-capacity 234496 --max-concurrency 1 --max-pending-requests 16 --prefill-chunk 1024 --kv-dtype rk8v4` |
| C1 / 112K vision | `--max-context 114688 --kv-capacity 114688 --max-concurrency 1 --max-pending-requests 8 --prefill-chunk 512 --default-max-tokens 1024 --vision` |
| C1 / 148K vision rk8v4 | `--max-context 151552 --kv-capacity 151552 --max-concurrency 1 --max-pending-requests 8 --prefill-chunk 512 --default-max-tokens 1024 --vision --kv-dtype rk8v4` |

### Sizing long-context profiles

Reservation is linear in capacity and an oversized run fails in under a second, printing
both numbers:

```
requested Engine runtime reservation requires 7285583104 bytes,
but only 7114079232 bytes are available for runtime capacity
```

So two failed probes at different capacities recover the whole model — no bisection
needed. Measured on this 3090 at C1/MTP3 with CUDA Graphs on:

```
bytes =   600,945,920 + tokens x 35,904   (int8,           7,114,079,232 available)
bytes =   600,913,152 + tokens x 27,200   (rk8v4,          7,114,079,232 available)
bytes = 2,567,478,272 + tokens x 35,904   (int8 vision,    6,818,359,808 available)
bytes = 2,567,441,408 + tokens x 27,200   (rk8v4 vision,   6,818,359,808 available)
```

`--vision` costs ~1.83 GiB of fixed reservation and ~282 MiB of extra weights, identical
for both KV dtypes. Each extra `--max-concurrency` slot costs ~409 MB (~390 MiB), also
dtype- and vision-independent: ~11,390 int8 tokens or ~15,035 rk8v4 tokens. Probe with
the flags the target profile will actually run.

| Profile | Ceiling that starts | First failure | Free at ceiling | Deployed |
| --- | --- | --- | --- | --- |
| `int8` | 181,312 | 181,376 | 75 MiB | 177,152 (217 MiB free, 60.7 tok/s) |
| `rk8v4` | 239,296 | 239,424 | 77 MiB | 234,496 (201 MiB free, 56.0 tok/s) |
| `int8 --vision` | 118,336 | 118,400 | 75 MiB | 114,688 (199 MiB free, 60.9 tok/s) |
| `rk8v4 --vision` | 156,224 | 156,288 | 75 MiB | 151,552 (195 MiB free, 53.1 tok/s) |

The artifact also caps `--max-context` at 262,144 independently of memory; probes above
that return the usage text rather than a reservation error.

Available memory drifts ~1.5 MB run to run, so the ceiling is not reproducible — the
deployed values keep ~200 MiB. `--no-cuda-graph` frees only the 86 MiB graph allowance
(~2.5K INT8 / ~3.2K rk8v4 tokens) and costs decode throughput; lower the context instead.

The startup ledger reports exactly what resolved:

```
KV capacity explicit resolved=177152 tokens pages=2768/2768 runtime=6.48 GiB
free-after-weights=6.62 GiB free-after-startup=219.00 MiB slack=144.09 MiB
graphs=8.00 MiB/86.00 MiB
```

`scripts/ninfer-probe.sh` and `scripts/ninfer-smoke.sh` automate the probe and a
one-request end-to-end check. Both take `<dtype> <tokens>` and read `NINFER_SERVE`:

```bash
nix build /etc/nixos#ninfer-3090
export NINFER_SERVE=$PWD/result/bin/ninfer-serve
./scripts/ninfer-probe.sh rk8v4 245760    # FIT rk8v4 245760 required=... available=...
./scripts/ninfer-smoke.sh rk8v4 234496    # loads, generates, prints the ledger
```

Only one process can own the GPU. Stop the resident llama-swap model first:

```bash
curl -s localhost:8080/unload -H "Authorization: Bearer $LLAMA_SWAP_KEY"
nvidia-smi   # confirm VRAM is free
```

Reaching 8081 from another machine needs a firewall hole (only 8080 is declared):

```bash
sudo nixos-firewall-tool open tcp 8081     # reverted on next firewall reload
# fallback: sudo iptables -I nixos-fw 1 -p tcp --dport 8081 -j nixos-fw-accept
```

### 4. Smoke tests

No API key is configured when running directly, so requests are unauthenticated.

```bash
curl -s localhost:8081/health
curl -s localhost:8081/v1/models | jq

# Text generation
curl -s localhost:8081/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "qwen3.8-27b",
  "messages": [{"role": "user", "content": "Say hello in five words."}],
  "max_tokens": 128
}' | jq -r '.choices[0].message | .reasoning_content, .content'

# Reasoning effort (top-level field; "none" disables thinking)
curl -s localhost:8081/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "qwen3.8-27b",
  "messages": [{"role": "user", "content": "Is 1027 prime? Verify."}],
  "reasoning_effort": "xhigh",
  "max_tokens": 2048
}' | jq -r '.choices[0].message.reasoning_content'

# Streaming
curl -N localhost:8081/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "qwen3.8-27b",
  "messages": [{"role": "user", "content": "Count to ten."}],
  "stream": true, "stream_options": {"include_usage": true}
}'
```

Vision (`--vision` profile only):

```bash
IMG=$(base64 -w0 /path/to/image.png)
curl -s localhost:8081/v1/chat/completions -H 'Content-Type: application/json' -d "{
  \"model\": \"qwen3.8-27b\",
  \"messages\": [{\"role\": \"user\", \"content\": [
    {\"type\": \"text\", \"text\": \"Describe this image.\"},
    {\"type\": \"image_url\", \"image_url\": {\"url\": \"data:image/png;base64,${IMG}\"}}
  ]}],
  \"max_tokens\": 512
}" | jq -r '.choices[0].message.content'
```

Watch the server log for `TTFT`, decode tok/s, MTP acceptance, and peak VRAM to compare
against the numbers in the [upstream README](https://github.com/Don-Chad/ninfer-3090).

### 5. Concurrency check (C8 profile)

```bash
for i in $(seq 8); do
  curl -s localhost:8081/v1/chat/completions -H 'Content-Type: application/json' -d '{
    "model": "qwen3.8-27b",
    "messages": [{"role": "user", "content": "Write a 1000 token story."}],
    "max_tokens": 1024
  }' | jq -r '.usage.completion_tokens' &
done; wait
```

Aggregate throughput appears in the periodic stats line (`--log-stats-interval-ms`,
default 5000).

## syv-ai vLLM (Qwen3.8-27B)

### 1. Prepare the model

```bash
/etc/nixos/modules/nixos/services/llama-swap/setup-qwen38-vllm.sh
```

Pulls the pinned image (~9.5 GiB), then downloads and requantizes ~20 GiB into
`/mnt/ssd/vLLM/Models/Qwen3.8-27B-*`. CPU only — safe to run while llama-swap serves.
Idempotent; a re-run skips finished steps in seconds.

### 2. Run it directly

The container's launcher takes environment variables, not flags. Swap `CTX`/`VISION` to
match the profile under test; everything else is identical to what the model files render.

```bash
docker run --rm --name qwen38-syv-test --device=nvidia.com/gpu=1 --ipc=host \
  -e PREPARE=0 -e SPEC=dflash2 -e PREFIX_CACHE=1 -e CTX=huge \
  -v /mnt/ssd/vLLM/Models:/app/models \
  -v /mnt/ssd/vLLM/Cache/qwen38-syv:/cache \
  -p 8081:18020 \
  ghcr.io/syv-ai/qwen38-27b-rtx3090:sha-453104e single
```

| Profile | Env |
| --- | --- |
| 64K bf16 | `CTX=fast` |
| 128K int8 | `CTX=long` |
| 240K KVarN | `CTX=huge` |
| 64K vision | `CTX=fast VISION=1` |

CDI device 1 is the RTX 3090 (PCI order); `nvidia.com/gpu=all` plus
`CUDA_VISIBLE_DEVICES=0` does not work here — `AGENTS.md` explains why.

A cold start pays torch.compile, CUDA graph capture and FlashInfer JIT (measured 360 s);
the `/cache` mount brings later starts to 65-108 s. The startup log prints the attention
backend, the pinned pool and the token capacity it resolved — check those against the
table in `AGENTS.md` before trusting a geometry change.

Only one process can own the GPU; unload the resident llama-swap model first (see the
NInfer section above), and open 8081 the same way if reaching it from another machine.

**An interactive `docker` is not llama-swap's `docker`.** In a login shell `docker` is
podman-docker talking to the rootless socket; `lib/backends.nix` calls `${pkgs.docker}/bin/docker`,
which talks to the rootful one. Containers started by llama-swap are therefore invisible to
`docker ps` — inspect them through the same store path the config uses:

```bash
D=$(nix eval --raw /etc/nixos#nixosConfigurations.lin-va-desktop.pkgs.docker)/bin/docker
$D ps; $D logs --tail 20 qwen3.8-27b-vllm-240k-cuda0
```

### 3. Smoke tests

Direct runs answer to the upstream name `qwen3.8-27b`; through llama-swap the alias is
rewritten to it by `useModelName`. Reasoning knobs are `chat_template_kwargs`, not
top-level fields — this is where the syv stack differs from NInfer.

```bash
curl -s localhost:8081/health

curl -s localhost:8081/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "qwen3.8-27b",
  "messages": [{"role": "user", "content": "Say hello in five words."}],
  "max_tokens": 128
}' | jq -r '.choices[0].message | .reasoning_content, .content'

# Reasoning effort (low | medium | xhigh; enable_thinking false turns it off)
curl -s localhost:8081/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "qwen3.8-27b",
  "messages": [{"role": "user", "content": "Is 1027 prime? Verify."}],
  "chat_template_kwargs": {"reasoning_effort": "low"},
  "max_tokens": 2048
}' | jq -r '.choices[0].message.reasoning_content'
```

`verify.sh` probes a live server and prints the backend and pool it came up with; the
upstream benchmark suite runs against the same endpoint:

```bash
docker exec qwen38-syv-test bash verify.sh
docker exec qwen38-syv-test bash bench/run_benchmarks.sh single
```

## Testing through llama-swap instead

Once the direct run looks right, verify the wired config without a full deploy by
pointing a second llama-swap at the rendered JSON:

```bash
sudo cat /run/secrets/rendered/llama-swap.json > /tmp/ls.json   # includes API keys
nix build /etc/nixos#llama-swap
./result/bin/llama-swap --listen :8081 --config /tmp/ls.json

curl -s localhost:8081/v1/models -H "Authorization: Bearer $LLAMA_SWAP_KEY" | jq -r '.data[].id'
```

Requests then use the llama-swap alias as the model name
(`qwen3.8-27b-ninfer-173k-cuda0`), which is exactly what `--model-id` in the model file
must match. Delete `/tmp/ls.json` afterwards — it contains plaintext API keys.
