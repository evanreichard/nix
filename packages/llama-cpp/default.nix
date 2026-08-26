{ pkgs }:
let
  # Tracks upstream stable vX.Y.Z tags (since v0.1.0); bN tags are nightlies.
  # For HEAD builds use YYYYMMDD (e.g. "20260519").
  version = "0.3.0";
  # b-tag shipped by the v0.3.0 release.
  buildNumber = "10621";

  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "c1d0e7a004015f23bc0233470b747b596f29b264";
    hash = "sha256-eUHLOgWFy8N4vmrolnUxJYHPmtxmEmNGR4qL46mQs7A=";
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
    patches = (oldAttrs.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        url = "https://github.com/ggml-org/llama.cpp/pull/27742.diff";
        hash = "sha256-EYLqNZQyvaNggDfaXCkh2+Aq7SjtzU9OwyAQuKW9V9o=";
      })
    ];

    npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
    # Add SPIR-V Headers for Vulkan Backend
    # Newer llama.cpp requires spirv/unified1/spirv.hpp which isn't
    # pulled in by vulkan-headers alone.
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ pkgs.spirv-headers ];

    # Auto CPU Optimizations
    cmakeFlags = (builtins.filter (f: !(pkgs.lib.hasPrefix "-DLLAMA_BUILD_NUMBER" f)) oldAttrs.cmakeFlags) ++ [
      "-DLLAMA_BUILD_NUMBER:STRING=${buildNumber}"
      "-DGGML_CUDA_ENABLE_UNIFIED_MEMORY=1"
      "-DCMAKE_CUDA_ARCHITECTURES=61;86" # GTX 1070 / GTX 1080ti / RTX 3090
    ];

    # Disable Nix's march=native Stripping
    preConfigure = ''
      export NIX_ENFORCE_NO_NATIVE=0
      ${oldAttrs.preConfigure or ""}
    '';
  })
