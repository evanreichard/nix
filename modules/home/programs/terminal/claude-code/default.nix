{ lib
, pkgs
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.claude-code;
in
{
  options.${namespace}.programs.terminal.claude-code = {
    enable = lib.mkEnableOption "enable claude-code";
  };

  config = mkIf cfg.enable {
    programs.claude-code = {
      enable = true;
      mcpServers = {
        gopls = {
          type = "stdio";
          command = "gopls";
          args = [ "mcp" ];
        };
      };
    };

    programs.bash = lib.mkIf config.programs.bash.enable {
      shellAliases = {
        claude = "default_claude_custom";
      };

      initExtra =
        let
          baseUrl = "https://llm-api.va.reichard.io";
          authToken = "placeholder";
        in
        ''
          default_claude_custom() {
            local model_id=""
            while [[ $# -gt 0 ]]; do
              case $1 in
                -m|--model)
                  model_id="$2"
                  shift 2
                  ;;
                *)
                  shift
                  ;;
              esac
            done

            if [ -z "$model_id" ]; then
              echo "Error: Model ID is required. Usage: claude --model <model-id>"
              return 1
            fi

            ANTHROPIC_BASE_URL="${baseUrl}" \
            ANTHROPIC_AUTH_TOKEN="${authToken}" \
            ANTHROPIC_MODEL="$model_id" \
            ANTHROPIC_SMALL_FAST_MODEL="$model_id" \
            ${lib.getExe pkgs.claude-code}
          }

          # Completion Function
          _complete_claude_custom() {
            local cur=''${COMP_WORDS[COMP_CWORD]}
            local prev=''${COMP_WORDS[COMP_CWORD-1]}

            if [[ "$prev" == "-m" || "$prev" == "--model" ]]; then
              local models=( $(${pkgs.curl}/bin/curl -s -H "Authorization: Bearer ${authToken}" "${baseUrl}/v1/models" | ${pkgs.jq}/bin/jq -r '.data[].id' 2>/dev/null) )
              COMPREPLY=( $(compgen -W "''${models[*]}" -- "$cur") )
            fi
          }

          # Register Completion
          complete -F _complete_claude_custom claude
        '';
    };
  };
}
