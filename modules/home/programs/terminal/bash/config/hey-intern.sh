#!/usr/bin/env bash

MODEL="qwen3.6-27b-vllm-180k-cuda0"
SYSTEM_PROMPT="You are a shell command expert. Given a natural language query, generate a single shell command that accomplishes the task."

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RESET='\033[0m'

hey-intern() {
    local query="$*"

    # Help
    if [ -z "$query" ]; then
        echo "Usage: hey-intern \"your query here\"" >&2
        return 1
    fi

    # Execute LLM Request
    response=$(curl -s -X POST "https://llm-api.va.reichard.io/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg model "$MODEL" \
            --arg system "$SYSTEM_PROMPT" \
            --arg user "$query" \
            '{
                model: $model,
                temperature: 0.2,
                messages: [
                    {role: "system", content: $system},
                    {role: "user", content: $user}
                ],
                tools: [{
                    type: "function",
                    function: {
                        name: "generate_shell_command",
                        description: "Generate a shell command to answer a query",
                        parameters: {
                            type: "object",
                            properties: {
                                command: {type: "string", description: "The shell command to execute"}
                            },
                            required: ["command"]
                        }
                    }
                }]
            }')" | jq -r '.choices[0].message.tool_calls[0].function.arguments // empty')

    # Extract Command
    local command=$(echo "$response" | jq -r '.command // empty')

    if [ -n "$command" ]; then
        echo -e "\n  ${CYAN}${command}${RESET}\n"

        read -p "$(echo -e "${YELLOW}Would you like to run this command? [y/N]${RESET} ")" -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Running...${RESET}\n"
	    history -s "$command"
            eval "$command"
        fi
    else
        echo "Failed to generate a valid command from the response." >&2
        echo "Raw response: $response" >&2
        return 1
    fi
}

# Export Script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    hey-intern "$@"
fi
