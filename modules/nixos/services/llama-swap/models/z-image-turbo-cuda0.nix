{ pkgs, lib, backends, reasoning }:
{
  name = "Z-Image-Turbo";
  backend = "stable-diffusion";
  placement = "cuda0";
  checkEndpoint = "/";
  env = [ "CUDA_VISIBLE_DEVICES=0" ];
  cmd = ''
    ${backends.stable-diffusion-cpp}/bin/sd-server \
      --listen-port ''${PORT} \
      --diffusion-fa \
      --diffusion-model /mnt/ssd/StableDiffusion/ZImageTurbo/z-image-turbo-Q8_0.gguf \
      --vae /mnt/ssd/StableDiffusion/ZImageTurbo/ae.safetensors \
      --llm /mnt/ssd/Models/Qwen3/Qwen3-4B-Instruct-2507-Q4_K_M.gguf \
      --cfg-scale 1.0 \
      --steps 8 \
      --rng cuda
  '';
  metadata = {
    tags = [ "image-generation" ];
  };
}
