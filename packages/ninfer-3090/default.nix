{
  lib,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  autoAddDriverRunpath,
  cudaPackages,
  ffmpeg,
  curl,
}:
cudaPackages.backendStdenv.mkDerivation (finalAttrs: {
  pname = "ninfer-3090";
  version = "0.6.1-rtx3090";

  src = fetchFromGitHub {
    owner = "Don-Chad";
    repo = "ninfer-3090";
    rev = "7d715ccdaf58ad214fcbe61bb517c5e414c2a83d";
    hash = "sha256-UZTuW7QrvYCgOoY29zOW7DXj8GZHQ1SUt3+qO+w9lcY=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];

  buildInputs = [
    cudaPackages.cuda_cudart
    cudaPackages.cuda_cccl
    cudaPackages.cuda_nvtx
    ffmpeg
    curl
  ];

  cmakeFlags = [
    (lib.cmakeBool "NINFER_BUILD_APPS" true)
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeBool "NINFER_BUILD_BENCHMARKS" false)
    # Ampere Only - Upstream hard-fails on any other value; kernels are SM86-specific.
    (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" "86")
  ];

  ninjaFlags = [
    "ninfer"
    "ninfer-serve"
  ];

  # Manual Install - Upstream declares no install targets.
  installPhase = ''
    runHook preInstall
    install -Dm755 apps/ninfer apps/ninfer-serve -t $out/bin
    runHook postInstall
  '';

  meta = {
    description = "Qwen3.6/Qwen3.8 CUDA inference engine specialized for a single RTX 3090 (sm_86)";
    homepage = "https://github.com/Don-Chad/ninfer-3090";
    license = lib.licenses.asl20;
    mainProgram = "ninfer-serve";
    platforms = [ "x86_64-linux" ];
  };
})
