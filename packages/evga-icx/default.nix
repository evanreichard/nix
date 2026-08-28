{
  lib,
  stdenv,
  fetchgit,
  i2c-tools,
  pciutils,
  addDriverRunpath,
  cudaPackages,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "evga-icx";
  version = "2.1.3";

  src = fetchgit {
    url = "https://long-cat.net/gitea/moosecrap/evga-icx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+FBxc07siEL9azpB38ed2wxxOzaTKdzfBDkaXOzNIYA=";
  };

  nativeBuildInputs = [ addDriverRunpath ];

  buildInputs = [
    i2c-tools # libi2c
    pciutils # libpci, for the VRAM and hotspot sensors
    cudaPackages.cuda_nvml_dev
  ];

  # v2.1.3's Makefile takes its include and link paths from the environment.
  # cuda_nvml_dev keeps the link stub in a separate `stubs` output that
  # buildInputs does not put on the library search path.
  NIX_LDFLAGS = "-L${cudaPackages.cuda_nvml_dev.stubs}/lib/stubs";

  makeFlags = [
    "USE_NVML=1"
    "USE_LIBPCI=1"
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 evga-icx $out/bin/evga-icx
    runHook postInstall
  '';

  # Built against the NVML stub; the real driver library is resolved at runtime.
  # The cuda setup hook strips the stub directory from RUNPATH on its own.
  postFixup = ''
    addDriverRunpath $out/bin/evga-icx
  '';

  meta = {
    description = "Read iCX3 sensors and control fans on EVGA 30-series cards";
    longDescription = ''
      Reads the iCX3 microcontroller over I2C to report per-fan RPM and the nine
      onboard thermistors (GPU2, MEM1-3, PWR1-5), and reads VRAM and hotspot
      temperatures directly from the PCI device. These sensors are invisible to
      NVML, which reports only fan 0 and returns NOT_SUPPORTED for memory
      temperature on consumer boards.

      Requires the i2c-dev kernel module. VRAM and hotspot readings additionally
      need root and the iomem=relaxed kernel parameter.
    '';
    homepage = "https://long-cat.net/gitea/moosecrap/evga-icx";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "evga-icx";
  };
})
