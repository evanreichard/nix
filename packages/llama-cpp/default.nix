{ pkgs }:
let
  # Tracks upstream stable vX.Y.Z tags (since v0.1.0); bN tags are nightlies.
  # For HEAD builds use YYYYMMDD (e.g. "20260519").
  version = "0.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "bb4caa7540188872173c44d161602d9271386413";
    hash = "sha256-6cK5BMCCEUWL+590+WbrRInH3eEnsZ/S5m71IIBgDsA=";
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

    npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";

    # Add SPIR-V Headers for Vulkan Backend
    # Newer llama.cpp requires spirv/unified1/spirv.hpp which isn't
    # pulled in by vulkan-headers alone.
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ pkgs.spirv-headers ];

    # Auto CPU Optimizations
    cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
      "-DGGML_CUDA_ENABLE_UNIFIED_MEMORY=1"
      "-DCMAKE_CUDA_ARCHITECTURES=61;86" # GTX 1070 / GTX 1080ti / RTX 3090
    ];

    # Disable Nix's march=native Stripping
    preConfigure = ''
      export NIX_ENFORCE_NO_NATIVE=0
      ${oldAttrs.preConfigure or ""}
    '';
  })
