import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function replacePiWithClaudeCodeExtension(pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, ctx) => {
    // Anthropic-Only Guard - Other providers (e.g. OpenAI, Google) should
    // see the unmodified pi system prompt.
    if (ctx.model?.provider !== "anthropic") {
      return undefined;
    }

    // Replace "pi" With "claude code" - Exclude Literal ".pi" (e.g. Paths)
    // And "pi-coding-agent" (Package Name)
    const transformedSystemPrompt = event.systemPrompt.replace(
      /(?<!\.)pi(?!-coding-agent)/gi,
      "claude code",
    );

    if (transformedSystemPrompt === event.systemPrompt) {
      return undefined;
    }

    return {
      systemPrompt: transformedSystemPrompt,
    };
  });
}
