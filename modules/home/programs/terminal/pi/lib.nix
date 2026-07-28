{ lib }:
let
  inherit (lib)
    mapAttrs
    filterAttrs
    any
    flatten
    listToAttrs
    nameValuePair
    ;
in
{
  toPiModels =
    llamaSwapConfig:
    let
      hasType = type: model: any (t: t == type) (model.metadata.tags or [ ]);

      codingModels = filterAttrs (_name: model: hasType "coding" model) (llamaSwapConfig.models or { });

      localModels = mapAttrs
        (
          name: model:
            {
              id = name;
              inherit (model) name;
            }
            // (
              if model.macros.ctx or null != null then
                {
                  contextWindow = lib.toInt model.macros.ctx;
                }
              else
                { }
            )
            // (
              if hasType "vision" model then
                {
                  input = [
                    "text"
                    "image"
                  ];
                }
              else
                { }
            )
        )
        codingModels;

      peerModels = listToAttrs (
        flatten (
          map
            (
              peer:
              map
                (
                  modelName:
                  nameValuePair modelName {
                    id = modelName;
                    name = modelName;
                  }
                )
                peer.models
            )
            (builtins.attrValues (llamaSwapConfig.peers or { }))
        )
      );
    in
    builtins.attrValues (localModels // peerModels);
}
