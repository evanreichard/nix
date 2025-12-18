local wk = require("which-key")
wk.add({
	{ "<leader>a", group = "LLM" },        -- llm-config.lua
	{ "<leader>f", group = "Find" },       -- snacks-config.lua
	{ "<leader>l", group = "LSP" },        -- lsp-config.lua
	{ "<leader>g", group = "Git" },        -- git-config.lua
	{ "<leader>q", group = "Diagnostics" }, -- diagnostics-config.lua
	{ "<leader>d", group = "Debug" },      -- dap-config.lua
})
