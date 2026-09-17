# HyperQwen vLLM under llama-swap

Read `vllm.md` first: the levers are its levers, and the image's launcher pulls most of them
for us. This doc is only what is specific to this repo's deployment.

The stack: one prebuilt image
([syv-ai/HyperQwen](https://github.com/syv-ai/HyperQwen), renamed from
`syv-ai/qwen38-27b-rtx3090`; the GHCR package kept the old name, so its tags post-rename are
stale) carrying a patched
vLLM plus the DFlash2 drafter and the KVarN KV cache, run against one prepared model directory,
served by llama-swap as the `qwen3.8-27b-vllm-*` profiles. `hyperQwenCmd` in
`modules/nixos/services/llama-swap/lib/backends.nix` renders one `docker run` from a model id
plus `-e` values.

## What is ours to change

| Want to change                             | Where                                                                                               |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| Context/KV tier, vision, which checkpoint  | the model file's env list, `modules/nixos/services/llama-swap/models/qwen3.8-27b*vllm*.nix`         |
| vLLM version, patch set, launcher defaults | the image tag, in `lib/backends.nix` and `setup-qwen38-vllm.sh` (lockstep)                          |
| A serving flag                             | nowhere here — the launcher owns the command line, which is why the model files carry env vars only |

The resolved geometry per profile (KV dtype, pool, slots, `macros.ctx`) and the constraints
that keep it valid live in `modules/nixos/services/llama-swap/AGENTS.md`; that table is the
reference for "is this number right", not this doc. `macros.ctx` is published to pi as its
context window, so it must equal the launcher's `MAX_LEN` for the profile.

## Validate a profile

Boot it by hand on port 8081 — never through llama-swap, whose swap takes the whole card and
hides the boot log. Use the docker llama-swap itself calls (rootful on this host); with the
interactive `docker` (rootless) the image lands in a second store and llama-swap pulls it
again.

```bash
D=$(nix eval --raw /etc/nixos#nixosConfigurations.lin-va-desktop.pkgs.docker)/bin/docker
$D run --rm -d --name qwen38-probe --device=nvidia.com/gpu=1 --ipc=host \
  -e PREPARE=0 -e SPEC=dflash2 -e PREFIX_CACHE=1 -e REQ_METRICS=1 -e CTX=fast \
  -v /mnt/ssd/vLLM/Models:/app/models -v /mnt/ssd/vLLM/Cache/hyperqwen:/cache \
  -p 8081:18020 ghcr.io/syv-ai/hyperqwen:sha-6a15595 single
$D logs -f qwen38-probe        # 188-289 s on the first boot after a bump, 81 s warm
```

Then read back what it resolved and compare against the AGENTS table:

```bash
$D logs qwen38-probe | grep -aE "GPU KV cache size|Maximum concurrency"
$D logs qwen38-probe | grep -a draft_logits        # must be True
$D exec qwen38-probe sh -c 'tr "\0" " " < /proc/1/cmdline' | tr " " "\n" | grep -aA1 kv-cache-memory
```

`PREPARE=0` keeps the image's 19.5 GiB download out of a swap; `VERIFY` stays on and fails in
seconds if the model directory is missing or was prepared by an older layout. The launcher
sources `resolve_config.sh`, which refuses an unknown `CTX`/`SPEC` and prints the resolved
knobs — read `[effective-config]`, not the engine's args line, for `MODEL`/`MAX_LEN`/`MAX_SEQS`.

## Benchmark it

```bash
scripts/bench.sh --host evanreichard@10.0.20.100 --port 8081 --model qwen3.8-27b \
  --extra-json '{"chat_template_kwargs":{"enable_thinking":false}}'
```

The container serves `qwen3.8-27b`; through llama-swap the alias is
`qwen3.8-27b-vllm-<ctx>-cuda0`. `REQ_METRICS=1` is what supplies the `metrics` object the
shared bench reads. Depth is the number that moves: `CTX=fast` reads ~129 tok/s decode at
15.6k tokens against ~90 at 33.8k on `CTX=long` and ~61 at 39k on `CTX=huge`, so always run
the `deep` case before believing a short-prompt figure.

## Diagnose

| Symptom                                       | Cause to check                                                                                                                |
| --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `CUDA error: out of memory` at boot           | Something else owns the 3090 — llama-swap's resident container, or a leftover probe. Unload in llama-swap's UI, then boot     |
| Decode well below the AGENTS baseline         | The drafter's draft-logits buffer: look for `draft_logits=True`. 0.28 needs `draft_sample_method` set or acceptance collapses |
| Pool or `max_model_len` differ from the table | `KV_MEM` / `MAX_LEN` in the launcher, or the deployed tag is not the one AGENTS documents                                     |
| A stream is cut mid-prefill through a proxy   | The launcher's `SSE_KEEP_ALIVE` (default 30 s); the flag only exists in trees carrying `patches/sse-keep-alive.patch`         |
| A llama-swap switch times out                 | `healthCheckTimeout` must exceed the profile's cold boot; a version bump re-pays it                                           |
| `VERIFY` fails in seconds                     | Model directory missing or stale — rerun `setup-qwen38-vllm.sh` (idempotent, CPU-only)                                        |

## Bumping the image tag

Two files, in lockstep: `hyperQwenImage` in `lib/backends.nix` and `IMAGE` in
`setup-qwen38-vllm.sh`. Then check the bump before touching the model directory: diff the new
tag for `KV_MEM` and `prepare/`. If neither moved, the prepared artifacts stay valid (the
0.27.1 → 0.28.0 bump was one of those) and only the first boot per profile re-pays
torch.compile, CUDA graph capture and FlashInfer JIT — a new vLLM version invalidates all
three, so budget 188-289 s against `healthCheckTimeout`. Update the module `AGENTS.md` numbers
when a pool or a baseline actually moves.

A bump that touches `prepare/` needs one `prepare` run over the mounted dirs even when nothing
is missing: the state check decides the requisition work, but the template steps (array
tool-call harden, effort-vocabulary translate) rewrite every dir's `chat_template.jinja`
unconditionally. Pass `-e MODEL=<dir>` for a checkpoint prepared outside the script — ours is
the uncensored body — or its template is skipped.

`bae2023 → 6a15595` moved neither `KV_MEM` (5261334938 / 5583457484) nor a requant step, but
added those two template steps, which rewrote all three dirs.

## Quirks

- **One CDI device, not `CUDA_VISIBLE_DEVICES`.** vLLM reads compute capability through NVML,
  which enumerates in PCI order and ignores `CUDA_VISIBLE_DEVICES`, so exposing both cards
  makes it see the 1080 Ti and refuse the quantized checkpoint. `--device=nvidia.com/gpu=1` is
  the 3090 here and leaves NVML and torch agreeing.
- **`/mnt/ssd` is exFAT: no hardlinks.** `prepare/fetch_fast_variant.py` shares shards by
  `os.link`, so the setup script runs `prepare` twice, the second time after placing those
  shards itself.
- **One process owns the 3090.** Idle llama-swap keeps its last model resident; check
  `$D ps` and `nvidia-smi` before any probe, and never run two.
- **Root actions need the user.** `sync-repo`, `nixos-rebuild`, `systemctl stop llama-swap`
  and reading `/run/secrets/rendered/llama-swap.json` all require it — ask rather than
  reaching for `sudo`.
