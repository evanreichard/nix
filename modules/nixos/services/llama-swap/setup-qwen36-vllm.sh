#!/usr/bin/env bash
# Setup script for vLLM Qwen3.6-27B on a single 3090.
#
# Idempotent - safe to re-run; skips steps already completed.
#
# Prerequisites: git (with git-lfs), docker

set -euo pipefail

# Model Directories
MODEL_DIR="/mnt/ssd/vLLM/Models"
MODEL_SUBDIR="qwen3.6-27b-autoround-int4"
PATCHES_DIR="/mnt/ssd/vLLM/Patches"
TEMPLATES_DIR="/mnt/ssd/vLLM/Templates"
CACHE_DIR="/mnt/ssd/vLLM/Cache"
GENESIS_DIR="${PATCHES_DIR}/genesis"
GENESIS_PIN="${GENESIS_PIN:-7b9fd319}"

# Timings Patch
TIMINGS_PATCH="${PATCHES_DIR}/patch_timings_1acd67a.py"
TIMINGS_PATCH_URL="${TIMINGS_PATCH_URL:-https://gitea.va.reichard.io/evan/nix/raw/branch/master/modules/nixos/services/llama-swap/patches/patch_timings_1acd67a.py}"

# Template
TEMPLATE="${TEMPLATES_DIR}/chat_template-v11.jinja"
TEMPLATE_URL="https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/main/qwen3.6/chat_template-v11.jinja"

# ---------- Preflight Checks ----------
for cmd in git git-lfs curl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' not found in PATH." >&2
    exit 1
  fi
done

# ---------- Create Directories ----------
echo "Creating directories..."
mkdir -p "${TEMPLATES_DIR}" "${MODEL_DIR}" "${PATCHES_DIR}" "${CACHE_DIR}/torch_compile" "${CACHE_DIR}/triton"

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

# ---------- Download URL Patch ----------
install_via_url() {
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

# ---------- Download Assets ----------
install_via_url "patch_timings_1acd67a.py" "${TIMINGS_PATCH_URL}" "${TIMINGS_PATCH}"
install_via_url "chat_template-v11.jinja" "${TEMPLATE_URL}" "${TEMPLATE}"

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
echo "  │   └── qwen3.6-27b-autoround-int4/           (model weights)"
echo "  ├── Templates/"
echo "  │   └── chat_template-v11.jinja               (chat template)"
echo "  ├── Cache/"
echo "  │   ├── torch_compile/                        (torch.compile cache)"
echo "  │   └── triton/                               (Triton kernel cache)"
echo "  └── Patches/"
echo "      ├── genesis/                              (Genesis @ ${GENESIS_PIN})"
echo "      │   └── vllm/_genesis/                    (mounted into container)"
echo "      └── patch_timings_1acd67a.py              (boot-time: llama.cpp-compatible timings)"
