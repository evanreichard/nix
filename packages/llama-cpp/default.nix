{ pkgs }:
let
  # Version MUST be an integer string.
  # For tagged releases use the tag number (e.g. "9222").
  # For HEAD builds use YYYYMMDD (e.g. "20260519").
  version = "9802";

  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "beac5309f1bc67534f509bf29420abf58fff063c";
    hash = "sha256-muVLC9PBzu6fRD5ddz5I4b1INRGsfgjkuqnMj4MUoqk=";
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

    # WebUI npm deps hash for our pinned src. Upstream nixpkgs builds the WebUI
    # from tools/ui via `npm run build` in preConfigure (offline, using these
    # deps), so no custom webui derivation / HF-bucket workaround is needed.
    npmDepsHash = "sha256-X1DZgmhS/zHTqDT5zq0kywwntthcJ9vRXeqyO3zz6UU=";

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
