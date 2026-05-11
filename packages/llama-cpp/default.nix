{ pkgs }:
(pkgs.llama-cpp.override {
  cudaSupport = true;
  blasSupport = true;
  rocmSupport = false;
  metalSupport = false;
  vulkanSupport = true;
}).overrideAttrs
  (oldAttrs: rec {
    version = "9048";
    src = pkgs.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "b${version}";
      hash = "sha256-lYtX0hLReCnFw1+xOKefly+WunuoN89ZFEFl5mK5pQ4=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };

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

    # Apply Patches
    patchFlags = [ "-p1" ];
    patches = (oldAttrs.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        name = "mtp.patch";
        url = "https://github.com/ggml-org/llama.cpp/pull/22673.patch";
        hash = "sha256-HqpchhOpxuw5mY4a/OCWGDr2Y32rC4FeOHuhaVt+mvY=";
      })
    ];
  })
