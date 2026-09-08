{ pkgs, lib, backends, reasoning }:
{
  name = "FLUX.2 Klein 9B";
  backend = "stable-diffusion";
  placement = "cuda0";
  checkEndpoint = "/";
  env = [ "CUDA_VISIBLE_DEVICES=0" ];
  cmd = ''
    ${backends.stable-diffusion-cpp}/bin/sd-server \
      --listen-port ''${PORT} \
      --diffusion-fa \
      --vae-tiling \
      --diffusion-model /mnt/ssd/StableDiffusion/Flux2Klein/flux-2-klein-9b-Q8_0.gguf \
      --vae /mnt/ssd/StableDiffusion/Flux2Klein/flux2_ae.safetensors \
      --llm /mnt/ssd/Models/Qwen3/Qwen3-8B-UD-Q4_K_XL.gguf \
      --cfg-scale 1.0 \
      --steps 4 \
      --sampling-method euler \
      --rng cuda
  '';
  metadata = {
    tags = [
      "image-edit"
      "image-generation"
    ];
  };
}
