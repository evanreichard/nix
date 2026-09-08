# The ID must be exactly `comfyui_auto` - llama-swap hardcodes it for the `/comfyui`
# endpoint, which also forces compat.ignoreWebsockets and raises concurrencyLimit. That
# handler only starts the model from its own root, so API clients go through
# `/upstream/comfyui_auto/...` instead.
{ backends }:
backends.comfyuiModel {
  name = "ComfyUI";
  backend = "comfyui";
  placement = "cuda0";
  cmd = backends.comfyuiCmd "comfyui_auto";
  metadata = {
    tags = [ "image-generation" ];
  };
}
