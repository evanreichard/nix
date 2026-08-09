import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function replacePiWithClaudeCodeExtension(pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, ctx) => {
    // Bidirectional Swap - The system prompt persists across a session, so a
    // mid-session model switch has to undo a previous rename, not just skip it.
    const isAnthropic = ctx.model?.provider === "anthropic";

    const transformedSystemPrompt = isAnthropic
      ? event.systemPrompt.replace(/(^|\s)pi(?![\w-])/gi, "$1claude code")
      : event.systemPrompt.replace(/(^|\s)claude code(?![\w-])/gi, "$1pi");

    if (transformedSystemPrompt === event.systemPrompt) {
      return undefined;
    }

    return {
      systemPrompt: transformedSystemPrompt,
    };
  });
}
