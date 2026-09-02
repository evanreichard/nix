# Helpers shared by every model definition under ./models.
#
# Not lib/default.nix: snowfall-lib treats every default.nix under modules/nixos as a NixOS
# module and would call this with module arguments instead of { pkgs }.
{ pkgs }:
let
  inherit (pkgs) lib;

  backends = import ./lib/backends.nix { inherit pkgs; };
  reasoning = import ./lib/reasoning.nix;
in
{
  inherit backends reasoning;

  mkMatrix = import ./lib/matrix.nix { inherit lib; };

  # Each file in ./models is one model, and its filename is the model ID. `backend` and
  # `placement` are ours, not llama-swap's, so the caller strips them before rendering; they
  # drive the concurrency matrix and default.nix's preset selection. Each model receives only
  # the arguments it declares.
  importModels =
    dir:
    let
      args = { inherit pkgs lib backends reasoning; };
    in
    lib.mapAttrs' (
      file: _:
      let
        model = import (dir + "/${file}");
      in
      lib.nameValuePair (lib.removeSuffix ".nix" file) (
        model (builtins.intersectAttrs (builtins.functionArgs model) args)
      )
    ) (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (builtins.readDir dir));
}
