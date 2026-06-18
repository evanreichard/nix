{ lib
, pkgs
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mapAttrs' mapAttrsToList nameValuePair filterAttrs;
  cfg = config.${namespace}.programs.terminal.scripts;

  # Script Registry - Each entry declares its runtime dependencies. The script
  # source lives in ./bin/<name>.sh and is exposed on PATH as <name> when enabled.
  # Add a script by dropping ./bin/<name>.sh and a one-line entry here, e.g.:
  #   scriptDefs = {
  #     plan-disk-burns = { runtimeInputs = with pkgs; [ smartmontools util-linux ]; };
  #     my-new-thing    = { runtimeInputs = with pkgs; [ jq curl ]; };
  #   };
  scriptDefs = {
    plan-disk-burns = { runtimeInputs = with pkgs; [ smartmontools util-linux ]; };
  };

  mkScript = name: def:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = def.runtimeInputs or [ ];
      text = builtins.readFile (./bin + "/${name}.sh");
    };
in
{
  options.${namespace}.programs.terminal.scripts =
    mapAttrs'
      (name: _: nameValuePair name { enable = mkEnableOption name; })
      scriptDefs;

  config = {
    home.packages =
      mapAttrsToList (name: def: mkScript name def)
        (filterAttrs (name: _: cfg.${name}.enable) scriptDefs);
  };
}
