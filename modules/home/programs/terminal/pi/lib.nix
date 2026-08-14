{ lib }:
let
  inherit (lib)
    mapAttrs
    filterAttrs
    any
    flatten
    listToAttrs
    nameValuePair
    optionalAttrs
    ;
in
{
  toPiModels =
    llamaSwapConfig:
    let
      hasType = type: model: any (t: t == type) (model.metadata.tags or [ ]);

      piReasoningLevels = [
        "minimal"
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];

      controlAttrs =
        controls: controlName: value:
        let
          control = controls.${controlName} or null;
        in
        optionalAttrs (control != null && control.location == "chat_template_kwargs") {
          ${control.parameter} = value;
        };

      mkThinkingLevelMap =
        reasoning:
        let
          controls = reasoning.controls or { };
          levelControl = controls.level or null;
          budgetControl = controls.budgetTokens or null;
          nativeLevels = if levelControl == null then [ ] else levelControl.values or [ ];
          supportsPiTokenBudget =
            budgetControl != null
            && budgetControl.location == "request"
            && budgetControl.parameter == "thinking_token_budget";
        in
        optionalAttrs ((reasoning.mode or "hybrid") == "always") { off = null; }
        // (
          if levelControl != null then
            listToAttrs (
              map (
                level: nameValuePair level (if builtins.elem level nativeLevels then level else null)
              ) piReasoningLevels
            )
          else if supportsPiTokenBudget then
            { }
          else
            {
              minimal = null;
              low = null;
              medium = null;
              high = "high";
              xhigh = null;
              max = null;
            }
        );

      mkReasoningCompat =
        reasoning:
        let
          controls = reasoning.controls or { };
          budgetControl = controls.budgetTokens or null;
          chatTemplateKwargs =
            controlAttrs controls "enabled" { "$var" = "thinking.enabled"; }
            // controlAttrs controls "level" { "$var" = "thinking.effort"; }
            // controlAttrs controls "preserve" (reasoning.defaults.preserve or true);
          supportsPiTokenBudget =
            budgetControl != null
            && budgetControl.location == "request"
            && budgetControl.parameter == "thinking_token_budget";
        in
        optionalAttrs (chatTemplateKwargs != { }) {
          thinkingFormat = "chat-template";
          inherit chatTemplateKwargs;
        }
        // optionalAttrs supportsPiTokenBudget {
          supportsThinkingTokenBudget = true;
        };

      codingModels = filterAttrs (_name: model: hasType "coding" model) (llamaSwapConfig.models or { });

      localModels = mapAttrs (
        name: model:
        let
          reasoning = model.metadata.reasoning or null;
          reasoningCompat = if reasoning == null then { } else mkReasoningCompat reasoning;
          reasoningAttrs =
            if reasoning != null then
              {
                reasoning = true;
                thinkingLevelMap = mkThinkingLevelMap reasoning;
              }
              // optionalAttrs (reasoningCompat != { }) {
                compat = reasoningCompat;
              }
            else
              optionalAttrs (hasType "reasoning" model) {
                reasoning = true;
              };
        in
        {
          id = name;
          inherit (model) name;
        }
        // optionalAttrs (model.macros.ctx or null != null) {
          contextWindow = lib.toInt model.macros.ctx;
        }
        // optionalAttrs (hasType "vision" model) {
          input = [
            "text"
            "image"
          ];
        }
        // reasoningAttrs
      ) codingModels;

      peerModels = listToAttrs (
        flatten (
          map
            (
              peer:
              map
                (
                  modelName:
                  nameValuePair modelName (
                    {
                      id = modelName;
                      name = modelName;
                    }
                    // optionalAttrs (peer.contextWindows ? ${modelName}) {
                      contextWindow = peer.contextWindows.${modelName};
                    }
                  )
                )
                peer.models
            )
            (builtins.attrValues (llamaSwapConfig.peers or { }))
        )
      );
    in
    builtins.attrValues (localModels // peerModels);
}
