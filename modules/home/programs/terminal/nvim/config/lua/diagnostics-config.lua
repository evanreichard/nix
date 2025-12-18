-- Diagnostics Mappings
local diagnostics_active = true
local toggle_diagnostics = function()
	diagnostics_active = not diagnostics_active
	if diagnostics_active then
		vim.diagnostic.enable()
	else
		vim.diagnostic.disable()
	end
end

local diagnostics_loclist_active = false
local toggle_diagnostics_loclist = function()
	diagnostics_loclist_active = not diagnostics_loclist_active
	if diagnostics_loclist_active then
		vim.diagnostic.setloclist()
	else
		vim.cmd("lclose")
	end
end

-- Create KeyMaps
local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<leader>qN", function()
	vim.diagnostic.goto_prev({ float = false })
end, vim.tbl_extend("force", { desc = "Previous Diagnostic" }, opts))
vim.keymap.set("n", "<leader>qe", vim.diagnostic.open_float,
	vim.tbl_extend("force", { desc = "Open Diagnostics" }, opts))
vim.keymap.set("n", "<leader>qt", toggle_diagnostics,
	vim.tbl_extend("force", { desc = "Toggle Inline Diagnostics" }, opts))
vim.keymap.set("n", "<leader>qn", function()
	vim.diagnostic.goto_next({ float = false })
end, vim.tbl_extend("force", { desc = "Next Diagnostic" }, opts))
vim.keymap.set("n", "<leader>qq", toggle_diagnostics_loclist,
	vim.tbl_extend("force", { desc = "Toggle Diagnostic List" }, opts))
