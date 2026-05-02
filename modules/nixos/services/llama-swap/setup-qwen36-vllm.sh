#!/usr/bin/env bash
# Setup script for vLLM Qwen3.6-27B on a single 3090.
#
# Downloads the model, clones Genesis patches (pinned), applies setup-time
# source patches to the Genesis tree, and fetches all boot-time sidecar
# patches into place under /mnt/ssd/vLLM/.
#
# Idempotent — safe to re-run; skips steps already completed.
#
# Prerequisites: git (with git-lfs), docker, python3

set -euo pipefail

MODEL_DIR="/mnt/ssd/vLLM/Models"
MODEL_SUBDIR="qwen3.6-27b-autoround-int4"
PATCHES_DIR="/mnt/ssd/vLLM/Patches"
CACHE_DIR="/mnt/ssd/vLLM/Cache"
GENESIS_DIR="${PATCHES_DIR}/genesis"

# Pin Genesis to the validated commit (bump requires re-testing all composes)
GENESIS_PIN="${GENESIS_PIN:-fc89395}"

TOLIST_PATCH="${PATCHES_DIR}/patch_tolist_cudagraph.py"
WORKSPACE_LOCK_PATCH="${PATCHES_DIR}/patch_workspace_lock_disable.py"
PN25_REGISTER_PATCH="${PATCHES_DIR}/patch_pn25_genesis_register_fix.py"
PN30_DST_PATCH="${PATCHES_DIR}/patch_pn30_dst_shaped_temp_fix.py"
PR40798_PATCH="${PATCHES_DIR}/patch_pr40798_workspace.py"
TIMINGS_PATCH="${PATCHES_DIR}/patch_timings_07351e088.py"
TIMINGS_PATCH_URL="${TIMINGS_PATCH_URL:-https://gitea.va.reichard.io/evan/nix/raw/branch/master/modules/nixos/services/llama-swap/patches/patch_timings_07351e088.py}"

# Base URL for sidecar patches (club-3090 repo)
PATCH_BASE_URL="https://raw.githubusercontent.com/noonghunna/club-3090/master/models/qwen3.6-27b/vllm/patches"

# ---------- Preflight Checks ----------
for cmd in git git-lfs curl python3; do
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
download_patch "${WORKSPACE_LOCK_PATCH}"
download_patch "${PN25_REGISTER_PATCH}"
download_patch "${PN30_DST_PATCH}"
download_patch "${PR40798_PATCH}"

# ---------- Apply Setup-Time Genesis Source Patches ----------
# These modify the Genesis checkout in-place. The Genesis tree is mounted
# read-only into the container, so these MUST run at setup time, not boot.

# The setup-time patches use hardcoded relative paths like
# "models/qwen3.6-27b/vllm/patches/genesis/vllm/_genesis/..."
# rooted at the club-3090 repo root. Our Genesis clone lives at
# ${PATCHES_DIR}/genesis, so we create a temporary symlink tree
# so the relative paths resolve correctly.
PATCH_WORKDIR="$(mktemp -d)"
mkdir -p "${PATCH_WORKDIR}/models/qwen3.6-27b/vllm/patches"
ln -sfn "${GENESIS_DIR}" "${PATCH_WORKDIR}/models/qwen3.6-27b/vllm/patches/genesis"

# PN25 Worker-Spawn Registration Fix
# Registers the PN25 opaque op at module import time instead of inside
# the compiled forward path. Required for TP=1 spawned workers.
if [ -f "${PN25_REGISTER_PATCH}" ]; then
  echo "Applying PN25 genesis register fix to Genesis tree..."
  (cd "${PATCH_WORKDIR}" && python3 "${PN25_REGISTER_PATCH}") || {
    echo "WARN: PN25 register fix did not apply cleanly. PN25 may not work in workers." >&2
  }
fi

# PN30 DS Conv-State Dst-Shaped Temp Fix
# Corrects DS layout corruption in PN30's speculative decode path by
# building a destination-shaped temp instead of compacting source tail.
if [ -f "${PN30_DST_PATCH}" ]; then
  echo "Applying PN30 dst-shaped temp fix to Genesis tree..."
  (cd "${PATCH_WORKDIR}" && python3 "${PN30_DST_PATCH}") || {
    echo "WARN: PN30 dst-shaped temp fix did not apply cleanly. DS layout may not work." >&2
  }
fi

# Clean Up Symlink Workdir
rm -rf "${PATCH_WORKDIR}"

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
echo "      ├── genesis/                               (Genesis v7.65 @ ${GENESIS_PIN})"
echo "      │   └── vllm/_genesis/                     (mounted into container, PN25+PN30 applied)"
echo "      ├── patch_tolist_cudagraph.py              (boot-time: cudagraph capture fix)"
echo "      ├── patch_workspace_lock_disable.py        (boot-time: v0.20 WorkspaceManager lock workaround)"
echo "      ├── patch_pn25_genesis_register_fix.py     (setup-time: applied to Genesis tree)"
echo "      ├── patch_pn30_dst_shaped_temp_fix.py      (setup-time: applied to Genesis tree)"
echo "      ├── patch_pr40798_workspace.py             (PR40798 workspace fix)"
echo "      └── patch_timings_07351e088.py             (boot-time: llama.cpp-compatible timings)"
