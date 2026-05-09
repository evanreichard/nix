#!/usr/bin/env bash
# Setup script for vLLM Qwen3.6-27B on a single 3090.
#
# Downloads the model, clones Genesis patches (pinned), applies setup-time
# source patches to the Genesis tree, and fetches all boot-time sidecar
# patches into place under /mnt/ssd/vLLM/.
#
# Idempotent - safe to re-run; skips steps already completed.
#
# Prerequisites: git (with git-lfs), docker

set -euo pipefail

# Model Directories
MODEL_DIR="/mnt/ssd/vLLM/Models"
MODEL_SUBDIR="qwen3.6-27b-autoround-int4"
PATCHES_DIR="/mnt/ssd/vLLM/Patches"
CACHE_DIR="/mnt/ssd/vLLM/Cache"
GENESIS_DIR="${PATCHES_DIR}/genesis"
GENESIS_PIN="${GENESIS_PIN:-7b9fd319}"

# 3090 Patches
BASE_3090_PATCH_URL="https://raw.githubusercontent.com/noonghunna/club-3090/v7.69-cliff2-test/models/qwen3.6-27b/vllm/patches"
INPUTS_EMBEDS_PATCH="${PATCHES_DIR}/patch_inputs_embeds_optional.py"

# Tool Parser Patch
TOOL_PARSER_PATCH="${PATCHES_DIR}/qwen3coder_tool_parser_deferred_commit.py"
TOOL_PARSER_PATCH_URL="${TOOL_PARSER_PATCH_URL:-https://raw.githubusercontent.com/noonghunna/club-3090/refs/heads/master/models/qwen3.6-27b/vllm/patches/local/qwen3coder_tool_parser_deferred_commit.py}"

# Timings Patch
TIMINGS_PATCH="${PATCHES_DIR}/patch_timings_07351e088.py"
TIMINGS_PATCH_URL="${TIMINGS_PATCH_URL:-https://gitea.va.reichard.io/evan/nix/raw/branch/master/modules/nixos/services/llama-swap/patches/patch_timings_07351e088.py}"

# ---------- Preflight Checks ----------
for cmd in git git-lfs curl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' not found in PATH." >&2
    exit 1
  fi
done

# ---------- Create Directories ----------
echo "Creating directories..."
mkdir -p "${MODEL_DIR}" "${PATCHES_DIR}" "${CACHE_DIR}/torch_compile" "${CACHE_DIR}/triton"

# ---------- Download Model ----------
if [ -d "${MODEL_DIR}/${MODEL_SUBDIR}/.git" ]; then
  echo "Model already cloned at ${MODEL_DIR}/${MODEL_SUBDIR}, skipping."
else
  echo "Cloning Lorbus/Qwen3.6-27B-int4-AutoRound (with LFS)..."
  git clone https://huggingface.co/Lorbus/Qwen3.6-27B-int4-AutoRound \
    "${MODEL_DIR}/${MODEL_SUBDIR}"
  echo "Model cloned."
fi

# ---------- Clone / Pin Genesis Patches ----------
if [ -d "${GENESIS_DIR}/.git" ]; then
  echo "Genesis already cloned - fetching + checking out ${GENESIS_PIN} ..."
  (cd "${GENESIS_DIR}" && git fetch origin && git checkout "${GENESIS_PIN}" 2>&1 | tail -3)
else
  echo "Cloning Genesis patches at ${GENESIS_PIN} ..."
  git clone https://github.com/Sandermage/genesis-vllm-patches "${GENESIS_DIR}"
  (cd "${GENESIS_DIR}" && git checkout "${GENESIS_PIN}")
fi

# Sanity Check
if [[ ! -d "${GENESIS_DIR}/vllm/_genesis" ]]; then
  echo "ERROR: genesis tree at ${GENESIS_PIN} missing vllm/_genesis package." >&2
  echo "       Re-run with GENESIS_PIN=<other-ref> to try a different version." >&2
  exit 1
fi
echo "Genesis pinned to ${GENESIS_PIN} ($(cd "${GENESIS_DIR}" && git rev-parse --short HEAD))"

# ---------- Download Sidecar Patches ----------
download_patch() {
  local dest="$1"
  local filename
  filename="$(basename "$dest")"
  if [ -f "${dest}" ]; then
    echo "Patch ${filename} already present, skipping."
  else
    echo "Downloading ${filename}..."
    curl -fsSL "${BASE_3090_PATCH_URL}/${filename}" -o "${dest}"
    echo "Patch ${filename} written."
  fi
}

download_patch "${INPUTS_EMBEDS_PATCH}"

# ---------- Download URL Patch ----------
install_url_patch() {
  local name="$1"
  local url="$2"
  local dest="$3"
  local tmp_patch
  tmp_patch="$(mktemp)"

  echo "Downloading ${name}..."
  curl -fsSL "${url}" -o "${tmp_patch}"

  if [ -f "${dest}" ] && cmp -s "${tmp_patch}" "${dest}"; then
    echo "${name} already current at ${dest}, skipping."
  else
    echo "Installing ${name} to ${dest}..."
    install -m 0644 "${tmp_patch}" "${dest}"
    echo "${name} installed."
  fi

  rm -f "${tmp_patch}"
}

# ---------- Download Boot-Time Patches ----------
install_url_patch "qwen3coder_tool_parser_deferred_commit.py" "${TOOL_PARSER_PATCH_URL}" "${TOOL_PARSER_PATCH}"
install_url_patch "patch_timings_07351e088.py" "${TIMINGS_PATCH_URL}" "${TIMINGS_PATCH}"

# ---------- Summary ----------
echo ""
echo "=== Setup Complete ==="
echo "  Model:   ${MODEL_DIR}/${MODEL_SUBDIR}"
echo "  Cache:   ${CACHE_DIR}/{torch_compile,triton}"
echo "  Genesis: ${GENESIS_DIR} (pinned: ${GENESIS_PIN})"
echo ""
echo "Expected layout:"
echo "  /mnt/ssd/vLLM/"
echo "  ├── Models/"
echo "  │   └── qwen3.6-27b-autoround-int4/          (model weights)"
echo "  ├── Cache/"
echo "  │   ├── torch_compile/                        (torch.compile cache)"
echo "  │   └── triton/                               (Triton kernel cache)"
echo "  └── Patches/"
echo "      ├── genesis/                               (Genesis @ ${GENESIS_PIN})"
echo "      │   └── vllm/_genesis/                     (mounted into container)"
echo "      ├── patch_inputs_embeds_optional.py        (boot-time: vllm#35975 backport, text-only models)"
echo "      ├── qwen3coder_tool_parser_deferred_commit.py (boot-time: qwen3coder SSE deferred commit fix)"
echo "      └── patch_timings_07351e088.py             (boot-time: llama.cpp-compatible timings)"
