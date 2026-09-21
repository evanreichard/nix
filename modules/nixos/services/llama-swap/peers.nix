{ lib }:
let
  registry = builtins.fromJSON (builtins.readFile ./providers/providers.json);

  catalogueFor = provider:
    builtins.fromJSON (
      builtins.readFile (
        (toString ./providers) + "/" + provider.modelsFile
      )
    );

  selectedModels = provider:
    let
      models = (catalogueFor provider).data;
    in
    if provider ? modelIds
    then builtins.filter (model: builtins.elem model.id provider.modelIds) models
    else models;

  toPeer = _: provider:
    let
      baseUrl = lib.removeSuffix "/" provider.baseUrl;
      models = selectedModels provider;
    in
    {
      proxy = "${lib.removeSuffix "/v1" baseUrl}/";
      models = map (model: model.id) models;
      contextWindows = builtins.listToAttrs (map (model: {
        name = model.id;
        value = model.context_length;
      }) models);
      apiKeySecret = provider.sopsSecret;
      apiKeySopsFile = provider.sopsFile;
    };
in
lib.mapAttrs toPeer registry
