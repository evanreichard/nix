# Reasoning profiles - the client-neutral source of truth for what each backend accepts.
#
# Record only verified native modes, levels, defaults and request controls. A profile says
# where a control lives, never how a particular client should send it: `location =
# "chat_template_kwargs"` denotes a nested template argument and `location = "request"` a
# top-level API field. pi-specific level mapping belongs in
# modules/home/programs/terminal/pi/lib.nix, which reads these.
let
  chatTemplateControl = parameter: {
    location = "chat_template_kwargs";
    inherit parameter;
  };
  requestControl = parameter: {
    location = "request";
    inherit parameter;
  };
  requestBudgetControl = parameter: {
    location = "request";
    inherit parameter;
    minimum = 0;
  };
in
{
  qwen36LlamaCpp = {
    mode = "hybrid";
    defaults = {
      enabled = true;
      preserve = true;
    };
    controls = {
      enabled = chatTemplateControl "enable_thinking";
      preserve = chatTemplateControl "preserve_thinking";
      budgetTokens = requestBudgetControl "reasoning_budget_tokens" // { unlimited = -1; };
    };
  };

  qwen36IkLlamaCpp = {
    mode = "hybrid";
    defaults = {
      enabled = true;
      preserve = true;
    };
    controls = {
      enabled = chatTemplateControl "enable_thinking";
      preserve = chatTemplateControl "preserve_thinking";
      budgetTokens = requestBudgetControl "thinking_budget_tokens" // { unlimited = -1; };
    };
  };

  qwen36Vllm = {
    mode = "hybrid";
    defaults = {
      enabled = true;
      preserve = false;
    };
    controls = {
      enabled = chatTemplateControl "enable_thinking";
      preserve = chatTemplateControl "preserve_thinking";
      budgetTokens = requestBudgetControl "thinking_token_budget";
    };
  };

  qwen38LlamaCpp = {
    mode = "hybrid";
    defaults = {
      enabled = true;
      level = "xhigh";
      preserve = true;
    };
    controls = {
      enabled = chatTemplateControl "enable_thinking";
      level = chatTemplateControl "reasoning_effort" // {
        values = [
          "low"
          "medium"
          "xhigh"
        ];
      };
      preserve = chatTemplateControl "preserve_thinking";
      budgetTokens = requestBudgetControl "reasoning_budget_tokens" // { unlimited = -1; };
    };
  };

  # Same Qwen3.8 chat template as the llama.cpp profile - enable_thinking, reasoning_effort
  # ('xhigh' by default, and anything outside low/medium/xhigh raises inside the template)
  # and preserve_thinking. No budget control: reasoning_budget_tokens is a llama.cpp server
  # field, and this stack carries none of the Genesis patches that add thinking_token_budget.
  qwen38Vllm = {
    mode = "hybrid";
    defaults = {
      enabled = true;
      level = "xhigh";
      preserve = true;
    };
    controls = {
      enabled = chatTemplateControl "enable_thinking";
      level = chatTemplateControl "reasoning_effort" // {
        values = [
          "low"
          "medium"
          "xhigh"
        ];
      };
      preserve = chatTemplateControl "preserve_thinking";
    };
  };

  # NInfer takes enable_thinking, preserve_thinking, and reasoning_effort as top-level
  # request fields; chat_template_kwargs rejects every key except preserve_thinking.
  # Effort default comes from the artifact's chat template, so no level default is recorded.
  qwen38Ninfer = {
    mode = "hybrid";
    defaults = {
      enabled = true;
      preserve = true;
    };
    controls = {
      enabled = requestControl "enable_thinking";
      preserve = requestControl "preserve_thinking";
      level = requestControl "reasoning_effort" // {
        values = [
          "low"
          "medium"
          "xhigh"
        ];
      };
    };
  };

  museGlimmerLlamaCpp = {
    mode = "always";
    defaults.level = "high";
    controls = {
      level = chatTemplateControl "reasoning_strength" // {
        values = [
          "low"
          "medium"
          "high"
          "xhigh"
        ];
      };
      budgetTokens = requestBudgetControl "reasoning_budget_tokens" // { unlimited = -1; };
    };
  };
}
