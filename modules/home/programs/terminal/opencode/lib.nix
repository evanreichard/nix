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
  # Convert llama-swap models to opencode format
  toOpencodeModels =
    llamaSwapConfig:
    let
      textGenModels = filterAttrs (name: model: any (t: t == "coding") (model.metadata.tags or [ ])) (
        llamaSwapConfig.models or { }
      );

      localModels = mapAttrs
        (
          name: model:
            {
              inherit (model) name;
            }
            // (
              if model.macros.ctx or null != null then
                {
                  limit = {
                    context = lib.toInt model.macros.ctx;
                    input = lib.toInt model.macros.ctx;
                    output = lib.toInt model.macros.ctx;
                  };
                }
              else
                { }
            )
        )
        textGenModels;

      peerModels = listToAttrs (
        flatten (
          map (peer: map (modelName: nameValuePair modelName { name = modelName; }) peer.models) (
            builtins.attrValues (llamaSwapConfig.peers or { })
          )
        )
      );
    in
    localModels // peerModels;
}
