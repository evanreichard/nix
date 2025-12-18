require("gitsigns").setup({
	current_line_blame = true,
	current_line_blame_opts = { delay = 0 },
	on_attach = function(bufnr)
		local gitsigns = require("gitsigns")

		local function map(mode, l, r, opts)
			opts = opts or {}
			opts.buffer = bufnr
			vim.keymap.set(mode, l, r, opts)
		end

		map("n", "<leader>gb", gitsigns.toggle_current_line_blame, { desc = "Git Blame Line" })
		map("n", "<leader>gB", function()
			gitsigns.blame_line({ full = true })
		end, { desc = "Git Blame Full" })
	end,
})


local function get_git_info()
	local abs_path = vim.fn.expand("%:p")
	local git_root = vim.fn.systemlist(
		"git -C " .. vim.fn.escape(vim.fn.fnamemodify(abs_path, ":h"), " ") .. " rev-parse --show-toplevel"
	)[1]

	if vim.v.shell_error ~= 0 then
		return
	end

	local git_repo = vim.fn.system("git remote get-url origin"):match("([^/:]+/[^/.]+)%.?[^/]*$"):gsub("\n", "")
	local git_branch = vim.fn.system("git rev-parse --abbrev-ref HEAD"):gsub("\n", "")

	return {
		file = vim.fn.fnamemodify(abs_path, ":s?" .. git_root .. "/??"),
		branch = git_branch,
		repo = git_repo,
	}
end

local function copy_git_link()
	local git_info = get_git_info()
	if git_info == nil then
		vim.notify("Failed to get git info", vim.log.levels.ERROR)
		return
	end

	local start_line = vim.fn.line("v")
	local end_line = vim.fn.line(".")

	local message = string.format(
		"https://github.com/%s/blob/%s/%s#L%d-L%d",
		git_info.repo,
		git_info.branch,
		git_info.file,
		start_line,
		end_line
	)
	vim.fn.setreg("+", message)
	vim.notify("Copied:\n\t" .. message, vim.log.levels.INFO)
end

-- Create KeyMaps
vim.keymap.set("v", "<Leader>gy", function() copy_git_link() end, { desc = "Copy GitHub Link" })
vim.keymap.set('n', '<leader>go', '<cmd>DiffviewOpen<CR>', { desc = "Open Diff - Current" })
vim.keymap.set('n', '<leader>gO', '<cmd>DiffviewOpen origin/main...HEAD<CR>', { desc = "Open Diff - Main" })
vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory<CR>', { desc = "Diff History" })
vim.keymap.set('n', '<leader>gH', '<cmd>DiffviewFileHistory --range=origin..HEAD<CR>', { desc = "Diff History - Main" })
vim.keymap.set('n', '<leader>gc', '<cmd>DiffviewClose<CR>', { desc = "Close Diff" })
