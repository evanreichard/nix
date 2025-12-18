-- Snacks Setup
local snacks = require("snacks")
snacks.setup({
	input = { enabled = true, style = "popup" },
	select = { enabled = true, style = "popup" },
})

-- Create KeyMaps
vim.keymap.set("n", "<leader>fb", snacks.picker.buffers, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fd", snacks.picker.diagnostics, { desc = "Diagnostics" })
vim.keymap.set("n", "<leader>ff", snacks.picker.files, { desc = "Find Files" })
vim.keymap.set("n", "<leader>fg", snacks.picker.grep, { desc = "Grep Files" })
vim.keymap.set("n", "<leader>fh", snacks.picker.help, { desc = "Help Tags" })
vim.keymap.set("n", "<leader>fj", snacks.picker.jumps, { desc = "Jump List" })
vim.keymap.set("n", "<leader>fl", function() snacks.terminal("lazygit") end, { desc = "LazyGit" })
vim.keymap.set("n", "<leader>fp", snacks.picker.gh_pr, { desc = "GitHub Pull Requests" })
vim.keymap.set("n", "<leader>fs", snacks.picker.lsp_symbols, { desc = "Symbols" })
vim.keymap.set("n", "<leader>fu", snacks.picker.undo, { desc = "Undo History" })
vim.keymap.set("n", "gI", snacks.picker.lsp_implementations, { desc = "LSP Implementations" })
vim.keymap.set("n", "gi", snacks.picker.lsp_incoming_calls, { desc = "LSP Incoming Calls" })
vim.keymap.set("n", "go", snacks.picker.lsp_outgoing_calls, { desc = "LSP Outgoing Calls" })
vim.keymap.set("n", "gr", snacks.picker.lsp_references, { desc = "LSP References" })
vim.keymap.set("n", [[<c-\>]], function() snacks.terminal() end, { desc = "Toggle Terminal" })
