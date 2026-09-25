{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen Image 2.1 Viggle Turbo";
  backend = "stable-diffusion";
  placement = "cuda0";
  checkEndpoint = "/";
  env = [ "CUDA_VISIBLE_DEVICES=0" ];
  cmd = ''
    ${backends.stable-diffusion-cpp}/bin/sd-server \
      --listen-port ''${PORT} \
      --diffusion-fa \
      --vae-tiling \
      --diffusion-model /mnt/ssd/StableDiffusion/QwenImage21/Base/transformer/diffusion_pytorch_model.safetensors.index.json \
      --vae /mnt/ssd/StableDiffusion/QwenImage21/qwen_image_2.1_vae_bf16.safetensors \
      --llm /mnt/ssd/Models/Qwen3VL/Qwen3VL-8B-Instruct-Q4_K_M.gguf \
      --llm_vision /mnt/ssd/Models/Qwen3VL/mmproj-Qwen3VL-8B-Instruct-Q8_0.gguf \
      --lora-model-dir /mnt/ssd/StableDiffusion/QwenImage21/Loras \
      --cfg-scale 1.0 \
      --sampling-method euler \
      --steps 6 \
      --sigmas "1.0,0.9375,0.875,0.75,0.5,0.25,0.0" \
      --rng cuda
  '';
  metadata = {
    tags = [
      "image-edit"
      "image-generation"
    ];
  };
}
