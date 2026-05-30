{ pkgs }:
let
  # Version MUST be an integer string.
  # For tagged releases use the tag number (e.g. "9222").
  # For HEAD builds use YYYYMMDD (e.g. "20260519").
  version = "9412";

  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "cb47092b007fcd5122eee2e8bb32ce972cdb23c2";
    hash = "sha256-x/2LOlEoaghgHEZp6m5ItXyNHGsvYmUrHYxKEtSeVSM=";
    leaveDotGit = true;
    postFetch = ''
      git -C "$out" rev-parse --short HEAD > $out/COMMIT
      find "$out" -name .git -print0 | xargs -0 rm -rf
    '';
  };

  # Pre-Built WebUI Assets
  # As of b9151 llama.cpp removed the prebuilt WebUI from the repo and tries to
  # curl them from a HuggingFace bucket at build time. That fails in the Nix
  # sandbox. We build the UI from source in a separate derivation and drop the
  # 4 output files into build/tools/ui/dist/ so cmake's "Priority 1: local
  # assets present" branch short-circuits the network fetch.
  #
  # As of b9180 the source dir was renamed tools/server/webui -> tools/ui, and
  # the vite plugin now writes to ../../build/tools/ui/dist relative to tools/ui.
  webuiNpmDeps = pkgs.fetchNpmDeps {
    name = "llama-webui-${version}-npm-deps";
    inherit src;
    sourceRoot = "${src.name}/tools/ui";
    hash = "sha256-Iyg8FpcTKf2UYHuK7mA3cTAqVaLcQPcS0YCa5Qf01Gc=";
  };

  webui = pkgs.buildNpmPackage {
    pname = "llama-webui";
    inherit version src;

    # Custom unpack: the vite plugin writes back into the source tree (tools/ui/dist),
    # so it must be writable. Plain sourceRoot leaves the parent dirs in the read-only
    # Nix store.
    unpackPhase = ''
      runHook preUnpack
      cp -r ${src} llama-src
      chmod -R u+w llama-src
      cd llama-src/tools/ui
      runHook postUnpack
    '';

    npmDeps = webuiNpmDeps;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      install -Dm644 dist/index.html   $out/index.html
      install -Dm644 dist/bundle.js    $out/bundle.js
      install -Dm644 dist/bundle.css   $out/bundle.css
      install -Dm644 dist/loading.html $out/loading.html
      runHook postInstall
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

    # Drop pre-built UI assets into tools/ui/dist/ so cmake's Priority 1 path
    # (SRC_DIST_DIR in scripts/ui-assets.cmake) picks them up and skips the HF
    # Bucket fetch. As of b9404 the lookup moved from build/tools/ui/dist to
    # tools/ui/dist.
    postPatch = ''
      ${oldAttrs.postPatch or ""}
      mkdir -p tools/ui/dist
      cp ${webui}/* tools/ui/dist/
    '';

    # Expose the WebUI sub-derivation so it can be built/tested in isolation:
    #   nix build .#llama-cpp.webui --builders ''
    passthru = (oldAttrs.passthru or { }) // { inherit webui; };
  })
