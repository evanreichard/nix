{ lib
, buildGoModule
, fetchgit
}:

buildGoModule rec {
  pname = "open-proxy";
  version = "unstable-2026-06-09";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/open-proxy.git";
    rev = "2cedcf448c984192d043b82ec9d614a349b0450b";
    hash = "sha256-R7JbWPkU8A6uABroNYBu+8K75xDK+VTuuBUPOaOEb+k=";
  };

  vendorHash = null;

  meta = {
    description = "Forward `open`/`xdg-open` from a remote VM to the host machine";
    homepage = "https://gitea.va.reichard.io/evan/open-proxy";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "open-proxy";
  };
}
