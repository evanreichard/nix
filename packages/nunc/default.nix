{ lib
, swiftPackages
, fetchgit
,
}:

swiftPackages.stdenv.mkDerivation rec {
  pname = "nunc";
  version = "unstable-2026-04-15";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/Nunc.git";
    rev = "95d95840aa0bc7b595293c6c5c9f53d120a90cca";
    hash = "sha256-UXBKcEuNnVO7WzuvmVqXMiJH7uvjLkcWiqBO0BhynsU=";
  };

  nativeBuildInputs = [
    swiftPackages.swift
    swiftPackages.swiftpm
  ];

  buildInputs = [
    swiftPackages.Foundation
    swiftPackages.XCTest
  ];

  buildPhase = ''
    runHook preBuild
    swift build -c release
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp .build/release/Nunc $out/bin/nunc
    runHook postInstall
  '';

  meta = {
    description = "Minimal floating clock overlay for macOS";
    homepage = "https://gitea.va.reichard.io/evan/Nunc";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "nunc";
    platforms = lib.platforms.darwin;
  };
}
