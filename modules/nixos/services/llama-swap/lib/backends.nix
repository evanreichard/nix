# Backend server binaries and the scaffolding that is identical across every model of a
# given backend. Deliberately not a command-line generator: a model's flags are where its
# tuning knowledge lives, and each one deviates (-np 2 -kvu, -ncmoe 26, -lm none,
# -ot per_layer_token_embd.weight=CPU), so `cmd` stays a readable invocation in the
# model's own file. Only invariants live here.
{ pkgs }:
let
  inherit (pkgs) lib;

  docker = "${pkgs.docker}/bin/docker";
in
rec {
  llama-cpp = pkgs.reichard.llama-cpp;
  ik-llama-cpp = pkgs.reichard.ik-llama-cpp;
  ninfer = pkgs.reichard.ninfer-3090;
  stable-diffusion-cpp = pkgs.reichard.stable-diffusion-cpp.override {
    cudaSupport = true;
  };

  inherit docker;

  # Every containerized model needs the same three things beside its command: a stop
  # command (without which a swap leaves the container running and the GPU occupied), an
  # explicit proxy target, and a readiness endpoint. Spell them once, and let a model
  # override checkEndpoint when its server has no /health.
  dockerModel =
    model:
    {
      checkEndpoint = "/health";
      proxy = "http://127.0.0.1:\${PORT}";
      cmdStop = "${docker} stop \${MODEL_ID}";
    }
    // model;

  # https://github.com/syv-ai/qwen38-27b-rtx3090
  #
  # One prebuilt image and one prepared model directory back every `qwen3.8-27b-vllm-*`
  # profile. The launcher inside derives attention backend, KV dtype, pinned pool size,
  # slot count and max-model-len from SPEC/CTX/VISION, so a profile is a handful of
  # environment variables rather than a command line - do not restate its flags here.
  #
  # Pinned to a commit tag rather than `latest`: the KV_MEM pool constants baked into the
  # launcher are calibrated per commit against a 24 GiB card, and the vLLM patch set is
  # applied at image build time. Keep in sync with IMAGE in setup-qwen38-vllm.sh.
  #
  # PREPARE=0 keeps the image's 19.5 GiB download and CPU requantization out of a model
  # swap; `setup-qwen38-vllm.sh` runs that step once. VERIFY stays on - it fails in
  # seconds when the model directory is missing or unpatched, instead of at first token.
  #
  # One CDI Device, Not CUDA_VISIBLE_DEVICES - vLLM resolves compute capability through
  # NVML, which enumerates in PCI order and ignores CUDA_VISIBLE_DEVICES, so exposing both
  # cards makes it read the 1080 Ti and refuse: "quantization method compressed-tensors is
  # not supported for the current GPU". CDI device 1 is the RTX 3090 here (PCI order), and
  # handing the container exactly one card leaves NVML and torch agreeing.
  qwen38SyvImage = "ghcr.io/syv-ai/qwen38-27b-rtx3090:sha-453104e";
  qwen38SyvCmd =
    modelId: env:
    lib.concatStringsSep " \\\n  " (
      [
        "${docker} run --rm --device=nvidia.com/gpu=1"
        "--name ${modelId}"
        "--ipc=host"
      ]
      ++ map (e: "-e ${e}") (
        [
          "PREPARE=0"
          "SPEC=dflash2"
          "PREFIX_CACHE=1"
          "REQ_METRICS=1"
        ]
        ++ env
      )
      ++ [
        "-v /mnt/ssd/vLLM/Models:/app/models"
        "-v /mnt/ssd/vLLM/Cache/qwen38-syv:/cache"
        "-p \${PORT}:18020"
        qwen38SyvImage
        "single"
      ]
    );

  # https://github.com/YanWenKun/ComfyUI-Docker
  #
  # The image declares `VOLUME /root` and its entrypoint materializes ComfyUI there on first
  # start, so the single /root bind mount carries everything mutable. The entrypoint also
  # passes `--listen --port 8188` already, so CLI_ARGS stays empty.
  #
  # One CDI Device, Not CUDA_VISIBLE_DEVICES - same NVML reasoning as the vLLM images above,
  # and device 1 is the RTX 3090 in PCI order. Exposing one card is what makes
  # `placement = "cuda0"` safe despite ComfyUI's unpredictable memory use.
  comfyuiImage = "docker.io/yanwk/comfyui-boot:cu130-slim-20260907";
  comfyuiCmd =
    modelId:
    lib.concatStringsSep " \\\n  " [
      "${docker} run --rm --device=nvidia.com/gpu=1"
      "--name ${modelId}"
      "--init"
      "-v /mnt/ssd/ComfyUI/storage:/root"
      "-v /mnt/ssd/StableDiffusion:/mnt/ssd/StableDiffusion:ro"
      "-p \${PORT}:8188"
      comfyuiImage
    ];

  # ComfyUI renders asynchronously - /prompt returns a prompt_id in milliseconds - and the
  # progress websocket is excluded from swap decisions by the compat.ignoreWebsockets that
  # /comfyui forces, so llama-swap sees an idle model throughout a render and would evict
  # mid-sampling. Drain first.
  #
  # `docker` stays absolute here and MUST NOT move to runtimeInputs: the `docker` in this
  # file's `let` is a binary path string, `let` shadows `with pkgs`, and the resulting PATH
  # entry silently resolves to rootless podman-docker, which cannot see rootful containers.
  comfyuiStop = pkgs.writeShellApplication {
    name = "comfyui-stop";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
    ];
    text = ''
      port="$1"
      name="$2"
      deadline=$((SECONDS + 200))

      while [ "$SECONDS" -lt "$deadline" ]; do
        if ! queued="$(curl -fsS --max-time 5 "http://127.0.0.1:$port/prompt" \
          | jq -r '.exec_info.queue_remaining // 0')"; then
          break
        fi
        if [ "$queued" = "0" ]; then
          break
        fi
        sleep 2
      done

      if ${docker} inspect --type container "$name" > /dev/null 2>&1; then
        ${docker} stop "$name"
      fi
    '';
  };

  # A swap's graceful stop window is healthCheckTimeout, not unloadTimeout (`doSwap` in
  # llama-swap's internal/router/base.go); unloadTimeout covers the TTL and manual paths.
  comfyuiModel =
    model:
    dockerModel (
      {
        checkEndpoint = "/system_stats";
        unloadTimeout = 240;
        cmdStop = "${comfyuiStop}/bin/comfyui-stop \${PORT} \${MODEL_ID}";
      }
      // model
    );
}
