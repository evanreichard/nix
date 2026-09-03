{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  openssl,
  autoAddDriverRunpath,
  config ? { },
  cudaSupport ? (config.cudaSupport or false),
  cudaPackages ? { },
  rocmSupport ? (config.rocmSupport or false),
  rocmPackages ? { },
  rocmGpuTargets ? (rocmPackages.clr.localGpuTargets or rocmPackages.clr.gpuTargets or [ ]),
  vulkanSupport ? false,
  vulkan-headers,
  vulkan-loader,
  glslang,
  shaderc,
  metalSupport ? (stdenv.hostPlatform.isDarwin),
  apple-sdk,
}:

let
  inherit (lib) cmakeBool cmakeFeature optionals optionalString;

  effectiveStdenv = if cudaSupport then cudaPackages.backendStdenv else stdenv;
in
effectiveStdenv.mkDerivation (finalAttrs: {
  pname = "audio-cpp";
  version = "0.7.1";

  src = fetchFromGitHub {
    owner = "0xShug0";
    repo = "audio.cpp";
    rev = "v${finalAttrs.version}";
    hash = "sha256-1h3UO2INVqVHrJ1A/Ljb9IffwRm/KLEPOmcss/O7mCo=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ]
  ++ optionals cudaSupport [
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ]
  ++ optionals rocmSupport [
    rocmPackages.clr
  ];

  buildInputs = [ openssl ]
  ++ optionals cudaSupport (
    with cudaPackages;
    [
      cuda_cccl
      cuda_cudart
      libcublas
    ]
  )
  ++ optionals rocmSupport (
    with rocmPackages;
    [
      clr
      hipblas
      rocblas
    ]
  )
  ++ optionals vulkanSupport [
    vulkan-headers
    vulkan-loader
    glslang
    shaderc
  ]
  ++ optionals metalSupport [
    apple-sdk
  ];

  strictDeps = true;

  cmakeFlags = [
    (cmakeBool "CMAKE_BUILD_RPATH_USE_ORIGIN" true)
    (cmakeBool "ENGINE_ENABLE_CUDA" cudaSupport)
    (cmakeBool "ENGINE_ENABLE_HIP" rocmSupport)
    (cmakeBool "ENGINE_ENABLE_VULKAN" vulkanSupport)
    (cmakeBool "ENGINE_ENABLE_METAL" metalSupport)
    (cmakeBool "ENGINE_ENABLE_NATIVE_CPU" true)
    (cmakeBool "ENGINE_BUILD_EXAMPLES" false)
    (cmakeBool "ENGINE_BUILD_TESTS" false)
    (cmakeBool "AUDIOCPP_BUILD_NATIVE_MODEL_MANAGER" true)
    (cmakeBool "AUDIOCPP_USE_SYSTEM_OPENSSL" true)
  ]
  ++ optionals cudaSupport [
    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaPackages.flags.cmakeCudaArchitecturesString)
  ]
  ++ optionals rocmSupport [
    (cmakeFeature "CMAKE_HIP_ARCHITECTURES" (builtins.concatStringsSep ";" rocmGpuTargets))
    (cmakeFeature "GPU_TARGETS" (builtins.concatStringsSep ";" rocmGpuTargets))
  ];

  env = lib.optionalAttrs rocmSupport {
    ROCM_PATH = "${rocmPackages.clr}";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 bin/audiocpp_cli bin/audiocpp_server bin/audiocpp_gguf $out/bin/
    install -m755 bin/audiocpp_model_manager $out/bin/

    # Model spec catalog and package specs are runtime data resolved by
    # upward directory search from the working directory; ship them alongside
    # the binaries so GGUF package specs resolve out of the box.
    cp -R $src/model_specs $out/model_specs

    runHook postInstall
  '';

  meta = with lib; {
    description = "Pure C++ inference engine for audio models (TTS, STT, VAD, music) built on ggml";
    homepage = "https://github.com/0xShug0/audio.cpp";
    license = licenses.asl20;
    platforms = platforms.unix;
    mainProgram = "audiocpp_cli";
  };
})
