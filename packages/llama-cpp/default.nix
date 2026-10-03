{ pkgs }:
let
  # Tracks upstream stable vX.Y.Z tags (since v0.1.0); bN tags are nightlies.
  # For HEAD builds use YYYYMMDD (e.g. "20260519").
  version = "11361";
  # Nightly b-tag used for this build.
  buildNumber = "11361";

  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "a4cb4c61fd9d9c2066c7c1747821d3d65b8943bd";
    hash = "sha256-JGHzaKVo0x6PPUPcArRnekvPBwI4FH3tDbJbXskPlDY=";
    leaveDotGit = true;
    postFetch = ''
      git -C "$out" rev-parse --short HEAD > $out/COMMIT
      find "$out" -name .git -print0 | xargs -0 rm -rf
    '';
  };
in
(pkgs.llama-cpp.override {
  cudaSupport = true;
  blasSupport = true;
  rocmSupport = false;
  metalSupport = false;
  vulkanSupport = true;
}).overrideAttrs
  (oldAttrs: {
    inherit version src;
    npmDepsHash = "sha256-a17M+L3nLdRnN6WMB6imPFmwqG2g8uv+gwN0XTAUrf8=";
    # Add SPIR-V Headers for Vulkan Backend
    # Newer llama.cpp requires spirv/unified1/spirv.hpp which isn't
    # pulled in by vulkan-headers alone.
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ pkgs.spirv-headers ];

    # CPU ISA - ggml sets GGML_NATIVE_DEFAULT=OFF whenever SOURCE_DATE_EPOCH is defined, which
    # Nix always does, and `if (GGML_NATIVE OR NOT GGML_NATIVE_DEFAULT)` then defaults every
    # instruction-set option to OFF, leaving a baseline x86-64 CPU backend. These are the
    # Zen 3 set (no AVX512), which is also what ggml's own variant table picks for it.
    # -march=native is not an option: the builder is not always the target.
    cmakeFlags = (builtins.filter (f: !(pkgs.lib.hasPrefix "-DLLAMA_BUILD_NUMBER" f)) oldAttrs.cmakeFlags) ++ [
      "-DLLAMA_BUILD_NUMBER:STRING=${buildNumber}"
      "-DGGML_CUDA_ENABLE_UNIFIED_MEMORY=1"
      "-DCMAKE_CUDA_ARCHITECTURES=61;86" # GTX 1070 / GTX 1080ti / RTX 3090
      "-DGGML_SSE42=ON"
      "-DGGML_AVX=ON"
      "-DGGML_AVX2=ON"
      "-DGGML_BMI2=ON"
      "-DGGML_FMA=ON"
      "-DGGML_F16C=ON"
    ];
  })
