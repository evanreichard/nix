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

      levelIndex = listToAttrs (lib.imap0 (index: level: nameValuePair level index) piReasoningLevels);

      # Nearest Native Level - pi forwards an unmapped level verbatim (`map[level] ?? level`),
      # so a null entry means a strict backend like NInfer answers 400 instead of falling back.
      # Resolving every pi level to a real native one keeps the whole UI ladder usable; ties go
      # to the higher effort.
      nearestNativeLevel =
        nativeLevels: level:
        let
          distance = native: let d = levelIndex.${native} - levelIndex.${level}; in if d < 0 then -d else d;
          closer =
            best: native:
            if best == null || distance native < distance best || levelIndex.${native} > levelIndex.${best} && distance native == distance best then
              native
            else
              best;
        in
        builtins.foldl' closer null nativeLevels;

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
                level:
                nameValuePair level (
                  if builtins.elem level nativeLevels then level else nearestNativeLevel nativeLevels level
                )
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
          enabledControl = controls.enabled or null;
          chatTemplateKwargs =
            controlAttrs controls "enabled" { "$var" = "thinking.enabled"; }
            // controlAttrs controls "level" { "$var" = "thinking.effort"; }
            // controlAttrs controls "preserve" (reasoning.defaults.preserve or true);
          supportsPiTokenBudget =
            budgetControl != null
            && budgetControl.location == "request"
            && budgetControl.parameter == "thinking_token_budget";
          # Top-Level Thinking Toggle - pi's "openai" format can only disable thinking through a
          # `thinkingLevelMap.off` string, which hybrid profiles do not have, so turning thinking
          # off would silently do nothing. Its "qwen" format sends `enable_thinking` alongside
          # `reasoning_effort`, which is exactly the pair NInfer accepts at the top level.
          sendsTopLevelThinkingToggle =
            enabledControl != null
            && enabledControl.location == "request"
            && enabledControl.parameter == "enable_thinking";
        in
        optionalAttrs (chatTemplateKwargs != { }) {
          thinkingFormat = "chat-template";
          inherit chatTemplateKwargs;
        }
        // optionalAttrs (chatTemplateKwargs == { } && sendsTopLevelThinkingToggle) {
          thinkingFormat = "qwen";
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
