{ pkgs }:
let
  # Version MUST be an integer string.
  # For tagged releases use the tag number (e.g. "9222").
  # For HEAD builds use YYYYMMDD (e.g. "20260519").
  version = "20260519";

  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "b28a2f372a4a470a90ad10f93654e5dc33e78949";
    hash = "sha256-SXOpTS3q5Vaik76fg2WQ1mmwAk9+KSMdLe4AErQQlOA=";
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

    # Custom unpack: the vite plugin writes to ../../build/tools/ui/dist, so
    # the whole tree from the repo root must be writable. Plain sourceRoot
    # leaves the parent dirs in the read-only Nix store.
    unpackPhase = ''
      runHook preUnpack
      cp -r ${src} llama-src
      chmod -R u+w llama-src
      cd llama-src/tools/ui
      runHook postUnpack
    '';

    npmDeps = webuiNpmDeps;

    # The vite plugin writes to ../../build/tools/ui/dist; ensure it exists.
    preBuild = ''
      mkdir -p ../../build/tools/ui/dist
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      install -Dm644 ../../build/tools/ui/dist/index.html   $out/index.html
      install -Dm644 ../../build/tools/ui/dist/bundle.js    $out/bundle.js
      install -Dm644 ../../build/tools/ui/dist/bundle.css   $out/bundle.css
      install -Dm644 ../../build/tools/ui/dist/loading.html $out/loading.html
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

    # Drop pre-built UI assets into build/tools/ui/dist/ so cmake's
    # Priority 1 path picks them up and skips the HF Bucket fetch.
    postPatch = ''
      ${oldAttrs.postPatch or ""}
      mkdir -p build/tools/ui/dist
      cp ${webui}/* build/tools/ui/dist/
    '';

    # Expose the WebUI sub-derivation so it can be built/tested in isolation:
    #   nix build .#llama-cpp.webui --builders ''
    passthru = (oldAttrs.passthru or { }) // { inherit webui; };
  })
