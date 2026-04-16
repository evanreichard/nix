import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function replacePiWithClaudeCodeExtension(pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    // Replace "pi" With "claude code" - Exclude Literal ".pi" (e.g. Paths)
    const transformedSystemPrompt = event.systemPrompt.replace(
      /(?<!\.)pi/gi,
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
