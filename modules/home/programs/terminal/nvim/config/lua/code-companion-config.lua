require("plugins.codecompanion.fidget-spinner"):init()
require("codecompanion").setup({
	opts = { log_level = "DEBUG" },
	adapters = {
		http = {
			["llama-swap"] = function()
				return require("codecompanion.adapters").extend("openai_compatible", {
					name = "llama-swap",
					formatted_name = "LlamaSwap",
					schema = {
						model = {
							default = "qwen3-coder-30b-instruct",
						},
					},
					env = {
						url = "http://10.0.20.100:8080",
						api_key = "none",
					},
				})
			end,
		},
	},
	strategies = {
		chat = { adapter = "llama-swap" },
		inline = { adapter = "llama-swap" },
	},
})
