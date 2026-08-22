{ lib }:
let
  inherit (lib)
    any
    filterAttrs
    flatten
    listToAttrs
    mapAttrs
    nameValuePair
    optionalAttrs
    ;

  # Canonical Omp Effort Ladder - `packages/catalog/src/effort.ts`; models.yml only accepts
  # these names in `thinking.efforts` / `thinking.effortMap` / `thinking.defaultLevel`.
  ompEfforts = [
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];

  effortIndex = listToAttrs (lib.imap0 (index: effort: nameValuePair effort index) ompEfforts);

  # Nearest Native Effort - omp drops any effort the model does not list, so a sparse native
  # ladder would hide most of the UI ladder. Advertising all six and remapping each onto the
  # closest native value keeps every tier selectable; ties go to the higher effort.
  nearestNativeEffort =
    natives: effort:
    let
      distance =
        native:
        let
          delta = effortIndex.${native} - effortIndex.${effort};
        in
        if delta < 0 then -delta else delta;
      closer =
        best: native:
        if
          best == null
          || distance native < distance best
          || distance native == distance best && effortIndex.${native} > effortIndex.${best}
        then
          native
        else
          best;
    in
    builtins.foldl' closer null natives;
in
{
  toOmpModels =
    llamaSwapConfig:
    let
      hasTag = tag: model: any (t: t == tag) (model.metadata.tags or [ ]);

      # Wire Placement - A control is only reachable if omp has a knob for its exact
      # parameter at its exact location. `reasoning_effort` is the only effort parameter omp
      # can emit per request; anything else (Muse-Glimmer's `reasoning_strength`) has to be
      # pinned as a static value because omp has no per-effort chat-template templating.
      effortIsRoutable =
        levelControl: levelControl != null && (levelControl.parameter or null) == "reasoning_effort";

      nativeEfforts = levelControl: if levelControl == null then [ ] else levelControl.values or [ ];

      # Pinned Effort - The single tier advertised when effort never reaches the wire. A
      # profile default is authoritative; otherwise `high` matches omp's own
      # `defaultThinkingLevel`, so thinking is simply on or off.
      pinnedEffort =
        reasoning:
        let
          levelControl = reasoning.controls.level or null;
          natives = nativeEfforts levelControl;
        in
        reasoning.defaults.level or (if natives == [ ] then "high" else lib.last natives);

      mkThinking =
        reasoning:
        let
          levelControl = reasoning.controls.level or null;
          natives = nativeEfforts levelControl;
          effortMap = filterAttrs (effort: wire: wire != effort) (
            listToAttrs (map (effort: nameValuePair effort (nearestNativeEffort natives effort)) ompEfforts)
          );
        in
        if effortIsRoutable levelControl && natives != [ ] then
          {
            mode = "effort";
            efforts = ompEfforts;
          }
          // optionalAttrs (effortMap != { }) { inherit effortMap; }
          // optionalAttrs (reasoning.defaults ? level) { defaultLevel = reasoning.defaults.level; }
        else
          {
            mode = "effort";
            efforts = [ (pinnedEffort reasoning) ];
          };

      # Static Body Fields - What the profile wants on every request but omp derives from model
      # identity instead of config: `preserve_thinking` (its `qwenPreserveThinking` only fires
      # for local/loopback base URLs) and an effort parameter omp cannot route.
      #
      # `allowTemplateKwargs` - `compat.extraBody` is `Object.assign`-ed onto the request after
      # the thinking encoder runs, so a static `chat_template_kwargs` replaces (never merges
      # with) the `enable_thinking` / `reasoning_effort` pair omp writes there. Template kwargs
      # are therefore only safe for dialects that leave that field alone.
      mkStaticBody =
        { reasoning, allowTemplateKwargs }:
        let
          controls = reasoning.controls or { };
          levelControl = controls.level or null;
          preserveControl = controls.preserve or null;
          preserveWanted = preserveControl != null && (reasoning.defaults.preserve or false);
          pinnedLevelAttrs =
            location:
            optionalAttrs
              (levelControl != null && !effortIsRoutable levelControl && levelControl.location == location)
              {
                ${levelControl.parameter} = pinnedEffort reasoning;
              };
          templateKwargs =
            optionalAttrs (preserveWanted && preserveControl.location == "chat_template_kwargs") {
              preserve_thinking = true;
            }
            // pinnedLevelAttrs "chat_template_kwargs";
        in
        optionalAttrs (preserveWanted && preserveControl.location == "request") { preserve_thinking = true; }
        // pinnedLevelAttrs "request"
        // optionalAttrs (allowTemplateKwargs && templateKwargs != { }) {
          chat_template_kwargs = templateKwargs;
        };

      mkCompat =
        reasoning:
        let
          controls = reasoning.controls or { };
          enabledControl = controls.enabled or null;
          levelControl = controls.level or null;
          enabledLocation = if enabledControl == null then null else enabledControl.location;
          routable = effortIsRoutable levelControl && nativeEfforts levelControl != [ ];
          staticBody =
            allowTemplateKwargs:
            mkStaticBody { inherit reasoning allowTemplateKwargs; };
        in
        if enabledLocation == "chat_template_kwargs" then
          # Chat-Template Dialect - omp owns `chat_template_kwargs` here (`enable_thinking`, plus
          # `reasoning_effort` when routable), so the profile's own kwargs have to be dropped:
          # `extraBody` would replace the whole field. `preserve_thinking` survives only when
          # omp's own identity-driven `qwenPreserveThinking` fires.
          {
            thinkingFormat = "qwen-chat-template";
            qwenTemplateReasoningEffort = routable && levelControl.location == "chat_template_kwargs";
          }
          // optionalAttrs (staticBody false != { }) { extraBody = staticBody false; }
        else if enabledLocation == "request" then
          # Top-Level Toggle - NInfer takes `enable_thinking`, `preserve_thinking`, and
          # `reasoning_effort` as request fields and rejects every other chat-template kwarg, so
          # the toggle rides `extraBody` (mirroring the bundled Qwen3.8 catalog entries) instead
          # of omp's `qwen` dialect, which also injects `chat_template_kwargs.reasoning_effort`.
          {
            thinkingFormat = "openai";
            supportsReasoningEffort = routable && levelControl.location == "request";
            extraBody = staticBody true // {
              enable_thinking = false;
            };
            whenThinking.extraBody = staticBody true // {
              enable_thinking = true;
            };
          }
        else
          {
            thinkingFormat = "openai";
            supportsReasoningEffort = routable && levelControl.location == "request";
          }
          // optionalAttrs (staticBody true != { }) { extraBody = staticBody true; };

      codingModels = filterAttrs (_name: model: hasTag "coding" model) (llamaSwapConfig.models or { });

      localModels = mapAttrs (
        name: model:
        let
          reasoning = model.metadata.reasoning or null;
          reasoningAttrs =
            if reasoning != null then
              {
                reasoning = true;
                thinking = mkThinking reasoning;
                compat = mkCompat reasoning;
              }
            else
              optionalAttrs (hasTag "reasoning" model) {
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
        // optionalAttrs (hasTag "vision" model) {
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
