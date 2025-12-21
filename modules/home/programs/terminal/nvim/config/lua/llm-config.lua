local llm_endpoint = "https://llm-api.va.reichard.io"
local llm_assistant_model = "devstral-small-2-instruct"
local llm_infill_model = "qwen2.5-coder-3b-instruct"

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

-- Copilot Configuration
vim.g.copilot_no_tab_map = true

-- LLama LLM FIM
vim.g.llama_config = {
	endpoint = llm_endpoint .. "/infill",
	model = llm_infill_model,
	n_predict = 2048,
	ring_n_chunks = 32,
	enable_at_startup = false,
}

-- Configure Code Companion
require("plugins.codecompanion.fidget-spinner"):init()
local codecompanion = require("codecompanion")
codecompanion.setup({
	display = {
		chat = {
			show_token_count = true,
			window = {
				layout = "float",
				width = 0.6,
			}
		}
	},
	adapters = {
		http = {
			opts = { show_defaults = false, },
			copilot = "copilot",
			llamaswap = function()
				return require("codecompanion.adapters").extend("openai_compatible", {
					formatted_name = "LlamaSwap",
					name = "llamaswap",
					schema = { model = { default = llm_assistant_model } },
					env = { url = llm_endpoint },
				})
			end,
		},
		acp = {
			opts = { show_defaults = false },
			opencode = "opencode",
		}
	},
	strategies = {
		chat = { adapter = "opencode" },
		inline = { adapter = "llamaswap" },
		cmd = { adapter = "llamaswap" },
	},
	chat = { dispay = "telescope" },
	memory = { opts = { chat = { enabled = true } } },
})

-- Create KeyMaps for Code Companion
vim.keymap.set("n", "<leader>aa", codecompanion.actions, { desc = "Actions" })
vim.keymap.set("n", "<leader>af", toggle_llm_fim_provider, { desc = "Toggle FIM (Llama / Copilot)" })
vim.keymap.set("n", "<leader>ao", function() require("snacks.terminal").toggle("opencode") end,
	{ desc = "Toggle OpenCode" })
vim.keymap.set("v", "<leader>ai", ":CodeCompanion<cr>", { desc = "Inline Prompt" })
vim.keymap.set({ "n", "v" }, "<leader>an", codecompanion.chat, { desc = "New Chat" })
vim.keymap.set({ "n", "t" }, "<leader>at", codecompanion.toggle, { desc = "Toggle Chat" })
vim.keymap.set('i', '<C-J>', 'copilot#Accept("\\<CR>")', {
	expr = true,
	replace_keycodes = false
})
