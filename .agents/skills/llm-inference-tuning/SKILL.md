---
name: llm-inference-tuning
description: Measure and tune local LLM inference on the inference host — llama.cpp (llama-server) and vLLM. Covers GPU placement, CPU/RAM offload, KV and context sizing, speculative decoding, quant choice, and the benchmark/diagnosis workflow. Use when asked to make a local model faster, fit it into VRAM, pick -ncmoe/-ts/-ot or a vLLM KV/context tier, diagnose low tok/s, or benchmark a deployment.
---

# LLM Inference Tuning

Measure the active bottleneck, then change only flags that can affect it. Which flags those
are, and how to read the result, depends on the backend — that lives in the references below.

## Target Host

Everything runs on `10.0.20.100` (`lin-va-desktop`), over ssh as your user:
`ssh -o BatchMode=yes 10.0.20.100 '<cmd>'`, and every script takes `--host`. Omit it to run
locally.

- `nvidia-smi`/CDI indices are GPU 0 = GTX 1080 Ti and GPU 1 = RTX 3090. With both
  exposed, llama.cpp reports the reverse CUDA order (`CUDA0` = RTX 3090, `CUDA1` = GTX
  1080 Ti); confirm with `llama-server --list-devices` before setting `-dev` or `-ts`.
- One process owns a GPU at a time, and llama-swap keeps its last model resident — check
  `nvidia-smi` on the host before starting anything.
- **Anything root needs the user**: `nixos-rebuild`, `systemctl stop llama-swap`, reading
  `/run/secrets/rendered/*`. Ask them to run it rather than reaching for `sudo`.

## Where things live

|           | Models                               | Definitions                                                                       |
| --------- | ------------------------------------ | --------------------------------------------------------------------------------- |
| llama.cpp | `/mnt/ssd/Models/**/*.gguf`          | `modules/nixos/services/llama-swap/models/*.nix`, flags in each model's own `cmd` |
| vLLM      | `/mnt/ssd/vLLM/Models/Qwen3.8-27B-*` | same directory, `backend = "vllm-hyperqwen"`, env vars only                        |

llama-swap fronts both, and its module guide — `modules/nixos/services/llama-swap/AGENTS.md`
— holds the invariants of every deployed model, including the vLLM profiles' geometry tables.
Read it before changing a model file.

## References

| Doc                       | Contents                                                                                                                                 |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `references/llama-cpp.md` | The whole llama.cpp workflow: deployment shapes, flag reference, bottleneck guide                                                        |
| `references/vllm.md`      | vLLM generically: the levers, what the boot log resolves, endpoints, measurement, diagnosis                                              |
| `references/hyperqwen.md` | This repo's vLLM image under llama-swap: what is ours to change, how to boot and verify a profile, the bump procedure. Assumes `vllm.md` |

## Scripts

- `scripts/bench.sh` — the four workload cases (`short`, `copy`, `prefill`, `deep`) against
  either backend's OpenAI-compatible endpoint; `--model` names what the server answers to and
  `--extra-json` merges fields into every request body

## Rules that hold everywhere

- Change one variable per comparison, and compare like-for-like: same prompts, same context,
  same sampling, same harness (server against server, not against a microbenchmark).
- Warm up once, generate at least 384 tokens, and measure decode at the depth users reach —
  depth moves decode far more than prompt length does.
- Never trust an estimator over `nvidia-smi` after the model is loaded, and keep ≥500 MiB free
  for the compute workspace.
- A performance claim carries the measurement that produced it; unmeasured advice is marked as
  such. Unverified guesses belong in the conversation, not in these docs.
