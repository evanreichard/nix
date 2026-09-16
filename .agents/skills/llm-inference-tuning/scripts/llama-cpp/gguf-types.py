#!/usr/bin/env python3
"""Dump a GGUF's tensor types, so a quant's real kernels are known before downloading it.

Filenames lie: unsloth's UD-Q3_K_XL and UD-Q2_K_XL carry IQ expert tensors. Reads only the
header, so a range request is enough:

    curl -sL -r 0-12582911 <url> -o /tmp/hdr.gguf && gguf-types.py /tmp/hdr.gguf

For a split model, point it at the shard holding the tensors (usually 00002-of-*), not the
metadata-only first shard.
"""
import struct, sys, collections

TYPES = {
    0: "F32", 1: "F16", 2: "Q4_0", 3: "Q4_1", 6: "Q5_0", 7: "Q5_1", 8: "Q8_0", 9: "Q8_1",
    10: "Q2_K", 11: "Q3_K", 12: "Q4_K", 13: "Q5_K", 14: "Q6_K", 15: "Q8_K",
    16: "IQ2_XXS", 17: "IQ2_XS", 18: "IQ3_XXS", 19: "IQ1_S", 20: "IQ4_NL", 21: "IQ3_S",
    22: "IQ2_S", 23: "IQ4_XS", 24: "I8", 25: "I16", 26: "I32", 27: "I64", 28: "F64",
    29: "IQ1_M", 30: "BF16", 39: "TQ1_0", 40: "TQ2_0",
}

f = open(sys.argv[1], "rb")
f.read(4)
ver, = struct.unpack("<I", f.read(4))
nt, = struct.unpack("<Q", f.read(8))
nkv, = struct.unpack("<Q", f.read(8))


def rs():
    n, = struct.unpack("<Q", f.read(8))
    return f.read(n).decode("utf-8", errors="replace")


def rv(t):
    if t in (0, 1, 7): return struct.unpack("<b", f.read(1))[0]
    if t == 2: return struct.unpack("<h", f.read(2))[0]
    if t == 3: return struct.unpack("<H", f.read(2))[0]
    if t == 4: return struct.unpack("<i", f.read(4))[0]
    if t == 5: return struct.unpack("<I", f.read(4))[0]
    if t == 6: return struct.unpack("<f", f.read(4))[0]
    if t == 8: return rs()
    if t == 9:
        at, = struct.unpack("<I", f.read(4))
        n, = struct.unpack("<Q", f.read(8))
        return [rv(at) for _ in range(n)]
    if t == 10: return struct.unpack("<q", f.read(8))[0]
    if t == 11: return struct.unpack("<Q", f.read(8))[0]
    if t == 12: return struct.unpack("<d", f.read(8))[0]
    raise Exception("type " + str(t))


for _ in range(nkv):
    rs()
    t, = struct.unpack("<I", f.read(4))
    rv(t)

hist = collections.Counter()
exps = collections.Counter()
for _ in range(nt):
    name = rs()
    nd, = struct.unpack("<I", f.read(4))
    dims = [struct.unpack("<Q", f.read(8))[0] for _ in range(nd)]
    ty, = struct.unpack("<I", f.read(4))
    struct.unpack("<Q", f.read(8))
    label = TYPES.get(ty, str(ty))
    hist[label] += 1
    if "exps" in name or "per_layer_token_embd" in name:
        key = "per_layer_token_embd" if "per_layer" in name else name.split(".")[-2]
        exps[(key, label)] += 1

print(sys.argv[1].split("/")[-1], "tensors=%d" % nt)
print("  all:", dict(hist))
for (k, t), c in sorted(exps.items()):
    print("  %-24s %-10s x%d" % (k, t, c))
