{ pkgs }:
let
  version = "9159";

  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    tag = "b${version}";
    hash = "sha256-y69ZmVFxo7bQvLTT6/GWwkb5j4Ll8eXSVXFpfXVkvyg=";
    leaveDotGit = true;
    postFetch = ''
      git -C "$out" rev-parse --short HEAD > $out/COMMIT
      find "$out" -name .git -print0 | xargs -0 rm -rf
    '';
  };

  # MTP Patch (PR #22673)
  # Use the .diff (squashed) endpoint, not .patch (mbox of commits).
  mtpPatch = pkgs.fetchpatch {
    name = "mtp.patch";
    url = "https://github.com/ggml-org/llama.cpp/pull/22673.diff";
    hash = "sha256-8W02V7oqq2/SzSrDUHEa5Zm+dGBFkasOiVinww3V85U=";
  };

  # Pre-Built WebUI Assets
  # As of b9151 llama.cpp removed the prebuilt WebUI from the repo and tries to
  # curl them from a HuggingFace bucket at build time. That fails in the Nix
  # sandbox. We build the WebUI from source in a separate derivation and drop
  # the 4 output files into tools/server/public/ so cmake's "Priority 1: local
  # assets present" branch short-circuits the network fetch.
  # Vendored npm deps. The npmDeps FOD uses default unpack and looks for
  # package-lock.json at sourceRoot, so point it directly at the webui dir.
  webuiNpmDeps = pkgs.fetchNpmDeps {
    name = "llama-webui-${version}-npm-deps";
    inherit src;
    sourceRoot = "${src.name}/tools/server/webui";
    hash = "sha256-WaEePrEZ7O/7deP2KJhe0AwiSKYA8HOqETmMHUkmBe0=";
  };

  webui = pkgs.buildNpmPackage {
    pname = "llama-webui";
    inherit version src;

    # Custom unpack: the vite plugin writes to ../public, so both webui/ and
    # public/ must be writable siblings under tools/server/. Plain sourceRoot
    # leaves the parent dirs in the read-only Nix store.
    unpackPhase = ''
      runHook preUnpack
      cp -r ${src}/tools/server tools-server
      chmod -R u+w tools-server
      cd tools-server/webui
      runHook postUnpack
    '';

    npmDeps = webuiNpmDeps;

    # The vite plugin writes to ../public; ensure it exists.
    preBuild = ''
      mkdir -p ../public
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      install -Dm644 ../public/index.html   $out/index.html
      install -Dm644 ../public/bundle.js    $out/bundle.js
      install -Dm644 ../public/bundle.css   $out/bundle.css
      install -Dm644 ../public/loading.html $out/loading.html
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

    # Apply Patches
    patchFlags = [ "-p1" ];
    patches = (oldAttrs.patches or [ ]) ++ [ mtpPatch ];

    # Drop pre-built WebUI assets into tools/server/public/ so cmake's
    # Priority 1 path picks them up and skips the HF Bucket fetch.
    postPatch = ''
      ${oldAttrs.postPatch or ""}
      mkdir -p tools/server/public
      cp ${webui}/* tools/server/public/
    '';

    # Expose the WebUI sub-derivation so it can be built/tested in isolation:
    #   nix build .#llama-cpp.webui --builders ''
    passthru = (oldAttrs.passthru or { }) // { inherit webui; };
  })
