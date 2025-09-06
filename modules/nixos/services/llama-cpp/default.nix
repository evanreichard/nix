{ config, pkgs, lib, namespace, ... }:
let
  inherit (lib) types mkIf mkEnableOption;
  inherit (lib.${namespace}) mkOpt;
  cfg = config.${namespace}.services.llama-cpp;

  modelDir = "/models";
  availableModels = {
    "qwen2.5-coder-7b-q8_0.gguf" = {
      url = "https://huggingface.co/ggml-org/Qwen2.5-Coder-7B-Q8_0-GGUF/resolve/main/qwen2.5-coder-7b-q8_0.gguf?download=true";
      flag = "--fim-qwen-7b-default";
    };
    "qwen2.5-coder-3b-q8_0.gguf" = {
      url = "https://huggingface.co/ggml-org/Qwen2.5-Coder-3B-Q8_0-GGUF/resolve/main/qwen2.5-coder-3b-q8_0.gguf?download=true";
      flag = "--fim-qwen-3b-default";
    };
  };
in
{
  options.${namespace}.services.llama-cpp = with types; {
    enable = mkEnableOption "llama-cpp support";
    modelName = mkOpt str "qwen2.5-coder-3b-q8_0.gguf" "model to use";
  };

  config =
    let
      modelPath = "${modelDir}/${cfg.modelName}";
    in
    mkIf cfg.enable {
      assertions = [
        {
          assertion = availableModels ? ${cfg.modelName};
          message = "Invalid model '${cfg.modelName}'. Available models: ${lib.concatStringsSep ", " (lib.attrNames availableModels)}";
        }
      ];

      systemd.services = {
        # LLama Download Model
        download-model = {
          description = "Download Model";
          wantedBy = [ "multi-user.target" ];
          before = [ "llama-cpp.service" ];
          path = [ pkgs.curl pkgs.coreutils ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "root";
            Group = "root";
          };
          script =
            let
              modelURL = availableModels.${cfg.modelName}.url;
            in
            ''
              set -euo pipefail

              if [ ! -f "${modelPath}" ]; then
                mkdir -p "${modelDir}"
                # Add -f flag to follow redirects and -L for location
                # Add --fail flag to exit with error on HTTP errors
                # Add -C - to resume interrupted downloads
                curl -f -L -C - \
                  -H "Accept: application/octet-stream" \
                  --retry 3 \
                  --retry-delay 5 \
                  --max-time 1800 \
                  "${modelURL}" \
                  -o "${modelPath}.tmp" && \
                mv "${modelPath}.tmp" "${modelPath}"
              fi
            '';
        };

        # Setup LLama API Service
        llama-cpp = {
          after = [ "download-model.service" ];
          requires = [ "download-model.service" ];
        };
      };

      services.llama-cpp = {
        enable = true;
        host = "0.0.0.0";
        port = 8012;
        openFirewall = true;
        model = "${modelPath}";

        package = (pkgs.llama-cpp.override {
          cudaSupport = true;
        }).overrideAttrs (oldAttrs: {
          cmakeFlags = oldAttrs.cmakeFlags ++ [
            "-DGGML_CUDA_ENABLE_UNIFIED_MEMORY=1"
            "-DCMAKE_CUDA_ARCHITECTURES=61" # GTX-1070

            # Disable CPU Instructions - Intel(R) Core(TM) i5-3570K CPU @ 3.40GHz
            "-DLLAMA_FMA=OFF"
            "-DLLAMA_AVX2=OFF"
            "-DLLAMA_AVX512=OFF"
            "-DGGML_FMA=OFF"
            "-DGGML_AVX2=OFF"
            "-DGGML_AVX512=OFF"
          ];
        });

        extraFlags = [ availableModels.${cfg.modelName}.flag ];
      };
    };
}
