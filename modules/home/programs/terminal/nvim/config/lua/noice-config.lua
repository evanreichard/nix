-- Noice Setup
require("noice").setup({
	-- Ignore (Snacks Priority)
	routes = {
		{
			filter = { event = "ui", kind = "input", },
			opts = { skip = true },
		},
		{
			filter = { event = "ui", kind = "select", },
			opts = { skip = true },
		},
	},
})
