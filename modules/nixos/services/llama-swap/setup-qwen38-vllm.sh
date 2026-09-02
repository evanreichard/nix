#!/usr/bin/env bash
# Setup script for the syv-ai patched-vLLM Qwen3.8-27B stack on a single 3090.
#
# Everything the server needs - vLLM 0.27.1, the patch set, the KVarN KV cache - is
# baked into the image; this script only prepares the model directory it mounts.
# Preparation is CPU-only (no GPU, safe to run while llama-swap is serving) and costs
# a ~19.5 GiB download plus a few minutes of requantization.
#
# Idempotent - the image's own prepare step resumes downloads and skips finished work.
#
# Prerequisites: docker (podman-docker on this host)

set -euo pipefail

# Keep in sync with qwen38SyvImage in config.nix: the launcher's pinned KV pool
# constants are calibrated per commit, so config and prepared artifacts move together.
IMAGE="${QWEN38_SYV_IMAGE:-ghcr.io/syv-ai/qwen38-27b-rtx3090:sha-453104e}"

MODEL_DIR="${QWEN38_SYV_MODEL_DIR:-/mnt/ssd/vLLM/Models}"
CACHE_DIR="${QWEN38_SYV_CACHE_DIR:-/mnt/ssd/vLLM/Cache/qwen38-syv}"

# ---------- Preflight Checks ----------
if ! command -v docker &>/dev/null; then
  echo "ERROR: 'docker' not found in PATH." >&2
  exit 1
fi

# ---------- Create Directories ----------
echo "Creating directories..."
mkdir -p "${MODEL_DIR}" "${CACHE_DIR}"

# ---------- Pull Image ----------
# ~9.5 GiB. Pinned tags are immutable, so a present image is the right one.
echo "Pulling ${IMAGE}..."
docker pull "${IMAGE}"

BASE_DIR="${MODEL_DIR}/Qwen3.8-27B-W4A16-AutoRound"
FAST_DIR="${BASE_DIR}-fast"

# ---------- Prepare Model ----------
# Downloads dbirks/Qwen3.8-27B-W4A16-AutoRound, requantizes lm_head / embeddings / the
# MTP module to int8, builds the 40k draft head and fetches the W4A16 DFlash2 block
# drafter every profile uses.
#
# FAST_VARIANT=0 - Its last step hardlinks the six unchanged shards into the -fast dir,
# and /mnt/ssd is exFAT, which has no hardlinks. Placing them here first is not just a
# workaround: the launcher prefers the fast variant, whose int4-GPTQ lm_head is 0.65 GB
# per verify against 1.27, and the pinned KV pool has no room for the difference.
echo "Preparing model (~19.5 GiB download, CPU-only, resumable)..."
docker run --rm \
  -e FAST_VARIANT=0 \
  -v "${MODEL_DIR}:/app/models" \
  -v "${CACHE_DIR}:/cache" \
  "${IMAGE}" prepare

# ---------- Place Shared Shards ----------
# Shards 1-6 are identical in both variants; only shard 7 and the head tensors differ.
# Link where the filesystem allows it, copy (~19 GiB) where it does not.
echo "Placing shared shards into $(basename "${FAST_DIR}")..."
mkdir -p "${FAST_DIR}"
for shard in "${BASE_DIR}"/model-0000[1-6]-of-00007.safetensors; do
  dst="${FAST_DIR}/$(basename "${shard}")"
  [ -e "${dst}" ] && continue
  ln "${shard}" "${dst}" 2>/dev/null || cp "${shard}" "${dst}"
done

# ---------- Assemble Fast Variant ----------
# Downloads the ~1 GiB of tensors that actually differ; the shards above are skipped.
echo "Assembling fast variant..."
docker run --rm \
  -v "${MODEL_DIR}:/app/models" \
  -v "${CACHE_DIR}:/cache" \
  "${IMAGE}" prepare

# ---------- Verify ----------
# Checks the patch set inside the image and that every requantization landed. The
# serving profiles run this too (VERIFY defaults on), so a failure here is a failure
# to start rather than a slow surprise at first token. It also asserts torch sees a
# CUDA device, hence the GPU here - preparation itself never touches it.
echo "Verifying..."
docker run --rm --device=nvidia.com/gpu=all \
  -e CUDA_VISIBLE_DEVICES=0 \
  -v "${MODEL_DIR}:/app/models" \
  -v "${CACHE_DIR}:/cache" \
  "${IMAGE}" verify --no-server

# ---------- Summary ----------
echo ""
echo "=== Setup Complete ==="
echo "  Models: ${MODEL_DIR}"
echo "  Cache:  ${CACHE_DIR}"
echo ""
echo "Expected layout:"
echo "  /mnt/ssd/vLLM/"
echo "  ├── Models/"
echo "  │   ├── Qwen3.8-27B-W4A16-AutoRound/          (base, requantized in place)"
echo "  │   ├── Qwen3.8-27B-W4A16-AutoRound-fast/     (int4-GPTQ heads; launcher prefers this)"
echo "  │   └── Qwen3.8-27B-DFlash2-W4A16/            (block drafter, SPEC=dflash2)"
echo "  └── Cache/"
echo "      └── qwen38-syv/                           (torch.compile, Triton, FlashInfer JIT)"
echo ""
echo "Served by llama-swap as:"
echo "  qwen3.8-27b-vllm-64k-cuda0                    (bf16 KV, 8 slots, fastest)"
echo "  qwen3.8-27b-vllm-128k-cuda0                   (int8 KV, 4 slots)"
echo "  qwen3.8-27b-vllm-240k-cuda0                   (KVarN 4/2-bit KV, 2 slots)"
echo "  qwen3.8-27b-vllm-64k-vl-cuda0                 (bf16 KV, vision tower)"
echo ""
echo "The first start of each profile pays torch.compile, CUDA graph capture and"
echo "FlashInfer JIT into ${CACHE_DIR}; later starts reuse it."
