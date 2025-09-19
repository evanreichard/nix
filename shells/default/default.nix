{ pkgs, ... }:

let
  sync-repo = pkgs.writeShellScriptBin "sync-repo" ''
    if [ -z "$1" ]; then
      echo "Usage: sync-repo <ip-address>"
      echo "Example: sync-repo 23.29.118.42"
      exit 1
    fi

    rsync -av \
      --exclude='.git' \
      --exclude='.direnv' \
      --exclude='_scratch' \
      . evanreichard@$1:/etc/nixos
  '';
in
pkgs.mkShell {
  name = "reichard-dev";

  buildInputs = with pkgs; [
    rsync
    sync-repo
  ];

  shellHook = ''
    echo "Use: sync-repo <ip-address> to sync repository"
  '';
}
