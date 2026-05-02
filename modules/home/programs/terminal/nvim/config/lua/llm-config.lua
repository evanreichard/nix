local llm_endpoint = "https://llm-api.va.reichard.io"
local llm_assistant_model = "vllm-qwen3.6-27b-tools-text "
local llm_infill_model = "qwen3.5-4b-thinking"
local current_fim = "llama"

-- Copilot Configuration
vim.g.copilot_no_tab_map = true
vim.g.copilot_filetypes = { ["*"] = true }

-- LLama LLM FIM
vim.g.llama_config = {
	endpoint = llm_endpoint .. "/infill",
	model = llm_infill_model,
	n_predict = 2048,
	ring_n_chunks = 32,
	enable_at_startup = (current_fim == "llama"), -- enable based on default
}

-- Toggle function for manual switching
local function switch_llm_fim_provider(switch_to)
	if switch_to == "llama" then
		vim.cmd("Copilot disable")
		vim.cmd("LlamaEnable")
		current_fim = "llama"
		vim.notify("Llama FIM enabled", vim.log.levels.INFO)
	else
		vim.cmd("Copilot enable")
		vim.cmd("LlamaDisable")
		current_fim = "copilot"
		vim.notify("Copilot FIM enabled", vim.log.levels.INFO)
	end
end

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
	},
	strategies = {
		chat = { adapter = "llamaswap" },
		inline = { adapter = "llamaswap" },
		cmd = { adapter = "llamaswap" },
	},
	chat = { display = "telescope" },
	memory = { opts = { chat = { enabled = true } } },
})

-- Create KeyMaps for Code Companion
vim.keymap.set("n", "<leader>aa", codecompanion.actions, { desc = "Actions" })
vim.keymap.set("n", "<leader>af", function()
	if current_fim == "llama" then
		switch_llm_fim_provider("copilot")
	else
		switch_llm_fim_provider("llama")
	end
end, { desc = "Toggle FIM (Llama / Copilot)" })
vim.keymap.set("n", "<leader>ao", function() require("snacks.terminal").toggle("opencode") end,
	{ desc = "Toggle OpenCode" })
vim.keymap.set("v", "<leader>ai", ":CodeCompanion<cr>", { desc = "Inline Prompt" })
vim.keymap.set({ "n", "v" }, "<leader>an", codecompanion.chat, { desc = "New Chat" })
vim.keymap.set({ "n", "t" }, "<leader>at", codecompanion.toggle, { desc = "Toggle Chat" })
vim.keymap.set('i', '<C-J>', 'copilot#Accept("\\<CR>")', {
	expr = true,
	replace_keycodes = false
})
