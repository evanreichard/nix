# Reference Index

Consulted from `SKILL.md`; not loaded unless the workflow needs them.

| Doc | Contents |
| --- | --- |
| `scenarios.md` | The three deployment shapes (single GPU, multi-GPU, GPU + CPU offload) and the ordered lever list for each |
| `knobs.md` | Flag-by-flag reference: placement, memory, compute, speculation, quant selection |
| `diagnostics.md` | Bottleneck classification table, bandwidth arithmetic, benchmark methodology, traps, quality validation |

## Style

- Defer to the target's `llama-server --help` over anything written here; flag names change between builds.
- Every performance claim carries the measurement that produced it, with the hardware it came from. Unmeasured advice is marked as such.
- Add a row to an existing table before creating a new doc. A new doc earns its place only when a topic needs more than a table.
