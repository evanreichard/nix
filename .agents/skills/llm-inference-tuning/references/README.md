# Reference Index

Consulted from `SKILL.md`; not loaded unless the workflow needs them. One doc per backend,
plus one for this repo's own deployment.

| Doc | Contents |
| --- | --- |
| `llama-cpp.md` | The whole llama.cpp workflow: deployment shapes, flag reference, bottleneck guide, benchmark rules |
| `vllm.md` | vLLM generically: the levers in order of effect, what the boot log resolves, endpoints and measurement, diagnosis |
| `syv-ai.md` | This repo's vLLM image under llama-swap — what is ours to change, booting and verifying a profile, the image-bump procedure, quirks. Assumes `vllm.md` |

## Style

- Defer to the target's `--help` over anything written here; flag names change between builds.
- Every performance claim carries the measurement that produced it, with the hardware it came from. Unmeasured advice is marked as such.
- Add a row to an existing table before creating a new doc. A new doc earns its place only when a topic needs more than a table — and a backend-specific doc must be readable without the others, except where it says otherwise (`syv-ai.md` assumes `vllm.md`).
