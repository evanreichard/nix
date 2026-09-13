# llama-swap — Manual Testing

How to exercise a backend by hand, without redeploying the host or restarting the
`llama-swap` service. Everything below runs on port **8081** so it never collides with
llama-swap on 8080.

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

Only one process can own the GPU, so unload the resident llama-swap model first:

```bash
curl -s localhost:8080/unload -H "Authorization: Bearer $LLAMA_SWAP_KEY"
nvidia-smi   # confirm VRAM is free
```

Reaching 8081 from another machine needs a firewall hole (only 8080 is declared):

```bash
sudo nixos-firewall-tool open tcp 8081     # reverted on next firewall reload
# fallback: sudo iptables -I nixos-fw 1 -p tcp --dport 8081 -j nixos-fw-accept
```

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
rewritten to it by `useModelName`. Reasoning knobs ride `chat_template_kwargs`, not
top-level request fields.

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
(`qwen3.8-27b-vllm-240k-cuda0`), which `useModelName` rewrites to the name the container
actually serves. Delete `/tmp/ls.json` afterwards — it contains plaintext API keys.
