{ backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 Flash Next (Strata IQ3_S)";
  backend = "strata";
  placement = "cuda0";
  healthCheckTimeout = 900;
  macros.ctx = "131072";
  cmd = backends.strataCmd "qwen3.8-flash-next-strata-sm86-cuda0" [
    "MODEL=IQ3_S"
  ];
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "vision"
      "reasoning"
    ];
    reasoning = reasoning.qwen38Strata;
    maxTokens = 32768;
    streamIdleTimeoutMs = 900000;
  };
}
