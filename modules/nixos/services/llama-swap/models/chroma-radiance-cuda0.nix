{ pkgs
, lib
, backends
, reasoning
,
}:
{
  name = "Chroma Radiance";
  backend = "stable-diffusion";
  placement = "cuda0";
  checkEndpoint = "/";
  env = [ "CUDA_VISIBLE_DEVICES=0" ];
  cmd = ''
    ${backends.stable-diffusion-cpp}/bin/sd-server \
      --listen-port ''${PORT} \
      --diffusion-fa --chroma-disable-dit-mask \
      --diffusion-model /mnt/ssd/StableDiffusion/Chroma/chroma_radiance_x0_q8.gguf \
      --t5xxl /mnt/ssd/StableDiffusion/Chroma/t5xxl_fp16.safetensors \
      --cfg-scale 4.0 \
      --sampling-method euler \
      --rng cuda
  '';
  metadata = {
    tags = [ "image-generation" ];
  };
}
