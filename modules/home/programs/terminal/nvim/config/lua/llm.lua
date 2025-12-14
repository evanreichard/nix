local llm_endpoint = "https://llm-api.va.reichard.io"
-- local llm_assistant_model = "gpt-oss-20b-thinking"
-- local llm_infill_model = "qwen2.5-coder-3b-instruct"

local llm_assistant_model = "qwen3-30b-2507-instruct"
local llm_infill_model = llm_assistant_model

-- Default Llama - Toggle Llama & Copilot
-- vim.g.copilot_filetypes = { ["*"] = false }
local current_mode = "copilot"
local function toggle_llm_fim_provider()
	if current_mode == "llama" then
		vim.g.copilot_filetypes = { ["*"] = true }
		vim.cmd("Copilot enable")
		vim.cmd("LlamaDisable")
		current_mode = "copilot"
		vim.notify("Copilot FIM enabled", vim.log.levels.INFO)
	else
		vim.g.copilot_filetypes = { ["*"] = true }
		vim.cmd("Copilot disable")
		vim.cmd("LlamaEnable")
		current_mode = "llama"
		vim.notify("Llama FIM enabled", vim.log.levels.INFO)
	end
end
vim.keymap.set("n", "<leader>cf", toggle_llm_fim_provider, { desc = "Toggle FIM (Llama / Copilot)" })

-- Configure LLama LLM FIM
vim.g.llama_config = {
	endpoint = llm_endpoint .. "/infill",
	model = llm_infill_model,
	n_predict = 2048,
	ring_n_chunks = 32,
	enable_at_startup = false,
}

-- Configure Code Companion
require("plugins.codecompanion.fidget-spinner"):init()
require("codecompanion").setup({
	display = { chat = { window = { layout = "float", width = 0.6 } } },
	adapters = {
		http = {
			opts = { show_defaults = false, },
			["llama-swap"] = function()
				return require("codecompanion.adapters").extend("openai_compatible", {
					name = "llama-swap",
					formatted_name = "LlamaSwap",
					schema = { model = { default = llm_assistant_model } },
					env = { url = llm_endpoint },
				})
			end,
			copilot = require("codecompanion.adapters.http.copilot"),
		},
		acp = { opts = { show_defaults = false } },
	},
	strategies = {
		chat = { adapter = "llama-swap" },
		inline = { adapter = "llama-swap" },
		cmd = { adapter = "llama-swap" },
	},
	chat = { dispay = "telescope" },
	memory = {
		opts = { chat = { enabled = true } },
		default = {
			description = "Collection of common files for all projects",
			files = {
				".clinerules",
				".cursorrules",
				".goosehints",
				".rules",
				".windsurfrules",
				".github/copilot-instructions.md",
				"AGENT.md",
				"AGENTS.md",
				".cursor/rules/",
				{ path = "CLAUDE.md",           parser = "claude" },
				{ path = "CLAUDE.local.md",     parser = "claude" },
				{ path = "~/.claude/CLAUDE.md", parser = "claude" },
			},
			is_default = true,
		},
	},
})
