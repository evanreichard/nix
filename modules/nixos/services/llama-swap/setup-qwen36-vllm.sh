#!/usr/bin/env bash
# Setup script for vLLM Qwen3.6-27B on a single 3090.
#
# Downloads the model, clones Genesis patches (pinned), applies setup-time
# source patches to the Genesis tree, and fetches all boot-time sidecar
# patches into place under /mnt/ssd/vLLM/.
#
# Idempotent — safe to re-run; skips steps already completed.
#
# Prerequisites: git (with git-lfs), docker

set -euo pipefail

MODEL_DIR="/mnt/ssd/vLLM/Models"
MODEL_SUBDIR="qwen3.6-27b-autoround-int4"
PATCHES_DIR="/mnt/ssd/vLLM/Patches"
CACHE_DIR="/mnt/ssd/vLLM/Cache"
GENESIS_DIR="${PATCHES_DIR}/genesis"

# Pin Genesis to the validated commit (bump requires re-testing all composes)
GENESIS_PIN="${GENESIS_PIN:-2db18df}"

TOLIST_PATCH="${PATCHES_DIR}/patch_tolist_cudagraph.py"
INPUTS_EMBEDS_PATCH="${PATCHES_DIR}/patch_inputs_embeds_optional.py"
WORKSPACE_LOCK_PATCH="${PATCHES_DIR}/patch_workspace_lock_disable.py"
PN25_REGISTER_PATCH="${PATCHES_DIR}/patch_pn25_genesis_register_fix.py"
PN30_DST_PATCH="${PATCHES_DIR}/patch_pn30_dst_shaped_temp_fix.py"
PR40798_PATCH="${PATCHES_DIR}/patch_pr40798_workspace.py"
TIMINGS_PATCH="${PATCHES_DIR}/patch_timings_07351e088.py"
TIMINGS_PATCH_URL="${TIMINGS_PATCH_URL:-https://gitea.va.reichard.io/evan/nix/raw/branch/master/modules/nixos/services/llama-swap/patches/patch_timings_07351e088.py}"

# Base URL for sidecar patches (club-3090 repo, v7.69-cliff2-test branch)
PATCH_BASE_URL="https://raw.githubusercontent.com/noonghunna/club-3090/v7.69-cliff2-test/models/qwen3.6-27b/vllm/patches"

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
  echo "Genesis already cloned — fetching + checking out ${GENESIS_PIN} ..."
  (cd "${GENESIS_DIR}" && git fetch origin && git checkout "${GENESIS_PIN}" 2>&1 | tail -3)
else
  echo "Cloning Genesis patches at ${GENESIS_PIN} ..."
  git clone https://github.com/Sandermage/genesis-vllm-patches "${GENESIS_DIR}"
  (cd "${GENESIS_DIR}" && git checkout "${GENESIS_PIN}")
fi

# Sanity Check — v7.14+ layout
if [[ ! -d "${GENESIS_DIR}/vllm/_genesis" ]]; then
  echo "ERROR: genesis tree at ${GENESIS_PIN} missing vllm/_genesis package." >&2
  echo "       Re-run with GENESIS_PIN=<other-ref> to try a different version." >&2
  exit 1
fi
echo "Genesis pinned to ${GENESIS_PIN} ($(cd "${GENESIS_DIR}" && git rev-parse --short HEAD))"

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
    curl -fsSL "${PATCH_BASE_URL}/${filename}" -o "${dest}"
    echo "Patch ${filename} written."
  fi
}

download_patch "${TOLIST_PATCH}"
download_patch "${INPUTS_EMBEDS_PATCH}"
download_patch "${WORKSPACE_LOCK_PATCH}"
download_patch "${PN25_REGISTER_PATCH}"
download_patch "${PN30_DST_PATCH}"
download_patch "${PR40798_PATCH}"

# ---------- Download Timing Patch ----------
tmp_timings_patch="$(mktemp)"
trap 'rm -f "${tmp_timings_patch}"' EXIT

echo "Downloading patch_timings_07351e088.py from this repo..."
curl -fsSL "${TIMINGS_PATCH_URL}" -o "${tmp_timings_patch}"

if [ -f "${TIMINGS_PATCH}" ] && cmp -s "${tmp_timings_patch}" "${TIMINGS_PATCH}"; then
  echo "Timing patch already current at ${TIMINGS_PATCH}, skipping."
else
  echo "Installing timing patch to ${TIMINGS_PATCH}..."
  install -m 0644 "${tmp_timings_patch}" "${TIMINGS_PATCH}"
  echo "Timing patch installed."
fi

# ---------- Summary ----------
echo ""
echo "=== Setup Complete ==="
echo "  Model:   ${MODEL_DIR}/${MODEL_SUBDIR}"
echo "  Genesis: ${GENESIS_DIR} (pinned: ${GENESIS_PIN})"
echo "  Cache:   ${CACHE_DIR}/{torch_compile,triton}"
echo ""
echo "Expected layout:"
echo "  /mnt/ssd/vLLM/"
echo "  ├── Models/"
echo "  │   └── qwen3.6-27b-autoround-int4/          (model weights)"
echo "  ├── Cache/"
echo "  │   ├── torch_compile/                        (torch.compile cache)"
echo "  │   └── triton/                               (Triton kernel cache)"
echo "  └── Patches/"
echo "      ├── genesis/                               (Genesis v7.69 @ ${GENESIS_PIN})"
echo "      │   └── vllm/_genesis/                     (mounted into container; PN25+PN30+PN34 native)"
echo "      ├── patch_tolist_cudagraph.py              (boot-time: cudagraph capture fix)"
echo "      ├── patch_inputs_embeds_optional.py        (boot-time: vllm#35975 backport, text-only models)"
echo "      ├── patch_workspace_lock_disable.py        (rollback: superseded by PN34 in v7.69)"
echo "      ├── patch_pn25_genesis_register_fix.py     (rollback: folded into v7.69 natively)"
echo "      ├── patch_pn30_dst_shaped_temp_fix.py      (rollback: folded into v7.69 natively)"
echo "      ├── patch_pr40798_workspace.py             (PR40798 workspace fix)"
echo "      └── patch_timings_07351e088.py             (boot-time: llama.cpp-compatible timings)"
