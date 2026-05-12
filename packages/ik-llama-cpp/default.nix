{ pkgs }:
let
  rev = "f9a93c37e2fc021760c3c1aa99cf74c73b7591a7";
  src = pkgs.fetchFromGitHub {
    owner = "ikawrakow";
    repo = "ik_llama.cpp";
    inherit rev;
    hash = "sha256-vBVosqBi8FyrllWGJOYsOYaNYAKoTTq6bn+i0Y32pu4=";
    leaveDotGit = true;
    postFetch = ''
      git -C "$out" rev-parse --short HEAD > $out/COMMIT
      find "$out" -name .git -print0 | xargs -0 rm -rf
    '';
  };
in
(pkgs.callPackage "${src}/.devops/nix/package.nix" {
  useCuda = true;
  useVulkan = true;
  useBlas = true;
  useRocm = false;
  useMetalKit = false;
}).overrideAttrs
  (oldAttrs: {
    inherit src;

    # Add SPIR-V Headers for Vulkan Backend
    # Newer ggml requires spirv/unified1/spirv.hpp which isn't pulled in by
    # vulkan-headers alone.
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ pkgs.spirv-headers ];

    # Auto CPU Optimizations + CUDA Arches
    # Appended after upstream's flags so CMAKE_CUDA_ARCHITECTURES wins.
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
