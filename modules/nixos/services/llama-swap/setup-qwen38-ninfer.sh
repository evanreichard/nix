#!/usr/bin/env bash
# Setup script for NInfer Qwen3.8-27B on a single 3090.
#
# Idempotent - safe to re-run; resumes partial downloads and skips a complete file.
#
# Prerequisites: curl, jq

set -euo pipefail

MODEL_DIR="${NINFER_MODEL_DIR:-/mnt/ssd/Ninfer/Models}"
MODEL_FILE="qwen3_8_27b.ninfer"
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"

HF_REPO="neroued/Qwen3.8-27B-NInfer"
MODEL_URL="https://huggingface.co/${HF_REPO}/resolve/main/${MODEL_FILE}"
HF_TREE_API="https://huggingface.co/api/models/${HF_REPO}/tree/main"

# ---------- Preflight Checks ----------
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' not found in PATH." >&2
    exit 1
  fi
done

mkdir -p "${MODEL_DIR}"

# ---------- Expected Size / Digest ----------
# The LFS pointer metadata gives both the byte size and the sha256, so a resumed
# or interrupted download can be validated without re-downloading 17 GiB.
entry="$(curl -fsSL "${HF_TREE_API}" | jq -r --arg f "${MODEL_FILE}" '.[] | select(.path == $f)')"
if [ -z "${entry}" ]; then
  echo "ERROR: ${MODEL_FILE} not found in ${HF_REPO}." >&2
  exit 1
fi
expected_size="$(jq -r '.lfs.size // .size' <<<"${entry}")"
expected_sha="$(jq -r '.lfs.oid // ""' <<<"${entry}")"

echo "Remote artifact: ${MODEL_FILE} (${expected_size} bytes)"

local_size() {
  [ -f "${MODEL_PATH}" ] && stat -c %s "${MODEL_PATH}" || echo 0
}

# ---------- Download ----------
if [ "$(local_size)" = "${expected_size}" ]; then
  echo "Model already complete at ${MODEL_PATH}, skipping download."
else
  echo "Downloading Qwen3.8-27B NInfer artifact (~17 GiB)..."
  if ! curl -L -C - --fail --progress-bar --output "${MODEL_PATH}" "${MODEL_URL}"; then
    echo "Download failed. Re-run this script to resume." >&2
    exit 1
  fi
fi

if [ "$(local_size)" != "${expected_size}" ]; then
  echo "ERROR: size mismatch - got $(local_size), expected ${expected_size}." >&2
  echo "       Re-run this script to resume the download." >&2
  exit 1
fi

# ---------- Optional Integrity Check ----------
# Hashing 17 GiB takes minutes, so it is opt-in rather than part of every run.
if [ "${NINFER_VERIFY_SHA:-0}" = "1" ] && [ -n "${expected_sha}" ]; then
  echo "Verifying sha256 (this takes several minutes)..."
  actual_sha="$(sha256sum "${MODEL_PATH}" | cut -d' ' -f1)"
  if [ "${actual_sha}" != "${expected_sha}" ]; then
    echo "ERROR: sha256 mismatch - got ${actual_sha}, expected ${expected_sha}." >&2
    exit 1
  fi
  echo "sha256 OK."
fi

chmod 0644 "${MODEL_PATH}"

# ---------- Summary ----------
echo ""
echo "=== Setup Complete ==="
echo "  Model: ${MODEL_PATH}"
echo ""
echo "Expected layout:"
echo "  /mnt/ssd/Ninfer/"
echo "  └── Models/"
echo "      └── ${MODEL_FILE}                       (Qwen3.8-27B groupwise artifact)"
echo ""
echo "Served by llama-swap as:"
echo "  qwen3.8-27b-ninfer-64k-cuda0                (C1, 64K, MTP3)"
echo "  qwen3.8-27b-ninfer-c8-8k-cuda0              (C8, 8K ctx / 16K KV pool)"
echo "  qwen3.8-27b-ninfer-32k-vl-cuda0             (vision, C1, 32K)"
echo ""
echo "Set NINFER_VERIFY_SHA=1 to checksum the artifact after download."
