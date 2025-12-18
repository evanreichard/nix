local llm_endpoint = "https://llm-api.va.reichard.io"
-- local llm_assistant_model = "gpt-oss-20b-thinking"
-- local llm_infill_model = "qwen2.5-coder-3b-instruct"

-- Available models: qwen3-30b-2507-instruct, qwen2.5-coder-3b-instruct
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

-- OpenCode Configuration
vim.g.opencode_opts = {
	provider = {
		enabled = "snacks",
		snacks = {
			win = {
				-- position = "float",
				enter = true,
				width = 0.5,
				-- height = 0.75,
			},
			start_insert = true,
			auto_insert = true,
		}
	}
}

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

-- Create KeyMaps
vim.keymap.set("n", "<leader>af", toggle_llm_fim_provider, { desc = "Toggle FIM (Llama / Copilot)" })
vim.keymap.set({ "n", "x" }, "<leader>ai", function() require("opencode").ask("@this: ", { submit = true }) end,
	{ desc = "Ask OpenCode" })
vim.keymap.set({ "n", "x" }, "<leader>aa", function() require("opencode").select() end,
	{ desc = "Execute OpenCode Action" })
vim.keymap.set({ "n", "t" }, "<leader>at", function() require("opencode").toggle() end, { desc = "Toggle OpenCode" })
vim.keymap.set('i', '<C-J>', 'copilot#Accept("\\<CR>")', {
	expr = true,
	replace_keycodes = false
})
