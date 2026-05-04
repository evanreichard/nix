{ lib
, buildGoModule
, fetchgit
}:

buildGoModule rec {
  pname = "conduit";
  version = "unstable-2026-05-03";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/conduit.git";
    rev = "9edea27148670b208c935c070ff3f58a416241b1";
    hash = "sha256-s8/ghyoAyFOvAMhE7vzckEZ8OxIF116OyJ4Uj30s65A=";
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
