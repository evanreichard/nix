#!/usr/bin/env bash
# Setup script for vLLM Qwen3.6-27B on a single 3090.
#
# Downloads the model, clones Genesis patches, and fetches all sidecar
# patches into place under /mnt/ssd/vLLM/.
#
# Idempotent — safe to re-run; skips steps already completed.
#
# Prerequisites: git (with git-lfs), docker

set -euo pipefail

MODEL_DIR="/mnt/ssd/vLLM/Models"
MODEL_SUBDIR="qwen3.6-27b-autoround-int4"
PATCHES_DIR="/mnt/ssd/vLLM/Patches"
GENESIS_DIR="${PATCHES_DIR}/genesis"
TOLIST_PATCH="${PATCHES_DIR}/patch_tolist_cudagraph.py"
PN12_FFN_PATCH="${PATCHES_DIR}/patch_pn12_ffn_pool_anchor.py"
PN12_COMPILE_PATCH="${PATCHES_DIR}/patch_pn12_compile_safe_custom_op.py"
FA_CLAMP_PATCH="${PATCHES_DIR}/patch_fa_max_seqlen_clamp.py"

# Base URL for sidecar patches (club-3090 repo, master branch)
PATCH_BASE_URL="https://raw.githubusercontent.com/noonghunna/club-3090/master/models/qwen3.6-27b/vllm/patches"

# ---------- Preflight Checks ----------
for cmd in git git-lfs; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' not found in PATH." >&2
    exit 1
  fi
done

# ---------- Create Directories ----------
echo "Creating directories..."
mkdir -p "${MODEL_DIR}" "${PATCHES_DIR}"

# ---------- Download Model ----------
if [ -d "${MODEL_DIR}/${MODEL_SUBDIR}/.git" ]; then
  echo "Model already cloned at ${MODEL_DIR}/${MODEL_SUBDIR}, skipping."
else
  echo "Cloning Lorbus/Qwen3.6-27B-int4-AutoRound (with LFS)..."
  git clone https://huggingface.co/Lorbus/Qwen3.6-27B-int4-AutoRound \
    "${MODEL_DIR}/${MODEL_SUBDIR}"
  echo "Model cloned."
fi

# ---------- Clone Genesis Patches ----------
if [ -d "${GENESIS_DIR}/.git" ]; then
  echo "Genesis patches already cloned at ${GENESIS_DIR}, pulling latest..."
  git -C "${GENESIS_DIR}" pull --ff-only || echo "Pull failed (non-fatal), using existing."
else
  echo "Cloning Genesis patches..."
  git clone https://github.com/Sandermage/genesis-vllm-patches "${GENESIS_DIR}"
  echo "Genesis patches cloned."
fi

# ---------- Download Sidecar Patches ----------
# Fetched from club-3090 repo so this script is self-contained.
download_patch() {
  local dest="$1"
  local filename
  filename="$(basename "$dest")"
  if [ -f "${dest}" ]; then
    echo "Patch ${filename} already present, skipping."
  else
    echo "Downloading ${filename}..."
    python3 -c "
import urllib.request, sys
url = '${PATCH_BASE_URL}/' + sys.argv[2]
try:
    urllib.request.urlretrieve(url, sys.argv[1])
    print('Downloaded from GitHub.')
except Exception as e:
    print(f'Download failed: {e}', file=sys.stderr)
    sys.exit(1)
" "${dest}" "${filename}"
    echo "Patch ${filename} written."
  fi
}

download_patch "${TOLIST_PATCH}"
download_patch "${PN12_FFN_PATCH}"
download_patch "${PN12_COMPILE_PATCH}"
download_patch "${FA_CLAMP_PATCH}"

# ---------- Summary ----------
echo ""
echo "=== Setup Complete ==="
echo "  Model:   ${MODEL_DIR}/${MODEL_SUBDIR}"
echo "  Genesis: ${GENESIS_DIR}"
echo "  Patch:   ${TOLIST_PATCH}"
echo ""
echo "Expected layout:"
echo "  /mnt/ssd/vLLM/"
echo "  ├── Models/"
echo "  │   └── qwen3.6-27b-autoround-int4/          (model weights)"
echo "  └── Patches/"
echo "      ├── genesis/                               (Genesis v7.14+ repo)"
echo "      │   └── vllm/_genesis/                     (mounted into container)"
echo "      ├── patch_tolist_cudagraph.py              (cudagraph capture fix)"
echo "      ├── patch_pn12_ffn_pool_anchor.py          (PN12 FFN pool anchor fix)"
echo "      ├── patch_pn12_compile_safe_custom_op.py   (PN12 compile-safe custom op)"
echo "      └── patch_fa_max_seqlen_clamp.py           (FA softmax_lse clamp — P104)"
