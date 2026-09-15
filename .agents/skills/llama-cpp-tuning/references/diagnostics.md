# Bottleneck Guide

Measure decode throughput with `scripts/profile.sh`, then follow the row matching the observed saturation:

| Observation | Bottleneck | Useful flags |
| --- | --- | --- |
| GPU utilization above 80% | GPU compute | Smaller weight quant, `-fa`, batch size |
| GPU low, CPU busy, RAM traffic below its ceiling | CPU compute | Cheaper CPU-resident quant, fewer CPU layers |
| GPU low, CPU busy, RAM traffic near its ceiling | RAM bandwidth | Smaller quant, fewer CPU layers |
| I/O wait above 5% | Disk streaming | `-lm none` or `--mlock` |
| Multiple GPUs underused | Device hops or synchronization | Fewer devices, different `-ts`, `-sm layer` |
| No resource saturated | Batch or synchronization overhead | Larger batch, fewer device boundaries |

For CPU-resident weights, estimate memory traffic as:

```
bytes/token ~= active_params * (cpu_layers / total_layers) * bytes_per_weight
achieved     = bytes/token * decode_tok_s
```

Compare `achieved` with measured RAM bandwidth. Near the ceiling means bandwidth-bound; well below it with busy CPU cores means compute-bound.

## Benchmark comparisons

- Warm up once, then measure at least 384 generated tokens.
- Measure prompt and decode throughput separately.
- Measure decode at the context depth users will reach.
- Keep prompts, context, and sampling settings identical.
- Change one variable per comparison.
- Keep at least 500 MiB VRAM free after loading.
- Compare server results with server results and `llama-bench` with `llama-bench`.
