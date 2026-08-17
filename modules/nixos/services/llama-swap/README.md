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
| C1 / 64K | `--max-context 65536 --kv-capacity 65536 --max-concurrency 1 --max-pending-requests 16 --prefill-chunk 1024` |
| C8 / 8K | `--max-context 8192 --kv-capacity 16384 --max-concurrency 8 --max-pending-requests 32 --prefill-chunk 1024` |
| Vision / 32K | `--max-context 32768 --kv-capacity 32768 --max-concurrency 1 --max-pending-requests 8 --prefill-chunk 512 --default-max-tokens 1024 --vision` |

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
(`qwen3.8-27b-ninfer-64k-cuda0`), which is exactly what `--model-id` in `config.nix`
must match. Delete `/tmp/ls.json` afterwards — it contains plaintext API keys.
