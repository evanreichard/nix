# llama-swap configuration.
#
# Models are one file per model under ./models, where the filename is the model ID; shared
# helpers are in ./lib. Per-backend knowledge - flag conventions, capacity arithmetic, request
# constraints - lives in AGENTS.md rather than in banner comments here.
{ pkgs }:
let
  inherit (pkgs) lib;

  llamaSwapLib = import ./lib.nix { inherit pkgs; };
  definitions = llamaSwapLib.importModels ./models;
  peerDefinitions = import ./peers.nix { inherit lib; };
in
{
  healthCheckTimeout = 500;

  models = lib.mapAttrs
    (
      _: model:
        # Internal References
        removeAttrs model [
          "backend"
          "placement"
        ]
    )
    definitions;

  matrix = llamaSwapLib.mkMatrix definitions;

  peers = lib.mapAttrs
    (_: peer: removeAttrs peer [ "apiKeySecret" "apiKeySopsFile" ])
    peerDefinitions;
}
