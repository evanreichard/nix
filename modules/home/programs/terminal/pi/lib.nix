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
      textGenModels = filterAttrs (name: model: any (t: t == "coding") (model.metadata.type or [ ])) (
        llamaSwapConfig.models or { }
      );

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
        )
        textGenModels;

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
