{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen Image Edit 2511";
  backend = "stable-diffusion";
  placement = "cuda0";
  checkEndpoint = "/";
  env = [ "CUDA_VISIBLE_DEVICES=0" ];
  cmd = ''
    ${backends.stable-diffusion-cpp}/bin/sd-server \
      --listen-port ''${PORT} \
      --diffusion-fa \
      --vae-tiling \
      --model-args qwen_image_zero_cond_t=true \
      --diffusion-model /mnt/ssd/StableDiffusion/QwenImage/qwen-image-edit-2511-Q5_K_M.gguf \
      --vae /mnt/ssd/StableDiffusion/QwenImage/qwen_image_vae.safetensors \
      --llm /mnt/ssd/Models/Qwen2.5/Qwen2.5-VL-7B-Instruct.Q4_K_M.gguf \
      --llm_vision /mnt/ssd/Models/Qwen2.5/Qwen2.5-VL-7B-Instruct.mmproj-Q8_0.gguf \
      --lora-model-dir /mnt/ssd/StableDiffusion/QwenImage/Loras \
      --cfg-scale 1.0 \
      --sampling-method euler_a \
      --scheduler simple \
      --flow-shift 3 \
      --steps 4 \
      --rng cuda
  '';
  metadata = {
    tags = [
      "image-edit"
      "image-generation"
    ];
  };
}
