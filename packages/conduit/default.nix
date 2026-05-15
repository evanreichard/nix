{ lib
, buildGoModule
, fetchgit
}:

buildGoModule rec {
  pname = "conduit";
  version = "unstable-2026-05-15";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/conduit.git";
    rev = "8dfb14f1e7f952bee92cad29703dba55fb156f0c";
    hash = "sha256-Fc0FHLCNBbEpOFFD0bHSDo1E5AsOzL2fJzHufleKBIo=";
  };

  vendorHash = "sha256-LOFT8eCNRm5Q2tVl7ifu4dB5cr828B/E2NJW5WiW0LI=";

  meta = {
    description = "Self-hosted tunneling service";
    homepage = "https://gitea.va.reichard.io/evan/conduit";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "conduit";
  };
}
