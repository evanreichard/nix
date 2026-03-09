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


local function git_cmd(dir, cmd)
	return vim.fn.system("git -C " .. vim.fn.escape(dir, " ") .. " " .. cmd)
end

local function git_cmd_list(dir, cmd)
	return vim.fn.systemlist("git -C " .. vim.fn.escape(dir, " ") .. " " .. cmd)
end

local function yank(message)
	vim.fn.setreg("+", message)
	vim.notify("Copied:\n\t" .. message, vim.log.levels.INFO)
end

local function get_git_info()
	local abs_path = vim.fn.expand("%:p")
	local file_dir = vim.fn.fnamemodify(abs_path, ":h")
	local git_root = git_cmd_list(file_dir, "rev-parse --show-toplevel")[1]

	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to get git info", vim.log.levels.ERROR)
		return
	end

	local git_repo = git_cmd(file_dir, "remote get-url origin"):match("([^/:]+/[^/.]+)%.?[^/]*$"):gsub("\n", "")
	local git_branch = git_cmd(file_dir, "rev-parse --abbrev-ref HEAD"):gsub("\n", "")

	return {
		abs_path = abs_path,
		file_dir = file_dir,
		file = vim.fn.fnamemodify(abs_path, ":s?" .. git_root .. "/??"),
		branch = git_branch,
		repo = git_repo,
	}
end

local function get_blame_info(file_dir, abs_path, line_num)
	local blame_output = git_cmd_list(
		file_dir,
		"blame -L " .. line_num .. "," .. line_num .. " --porcelain " .. vim.fn.escape(abs_path, " ")
	)

	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to get git blame", vim.log.levels.ERROR)
		return
	end

	local commit_hash = blame_output[1]:match("^(%S+)")
	local original_line = blame_output[1]:match("^%S+ (%d+)")
	local commit_file = nil

	for _, line in ipairs(blame_output) do
		local f = line:match("^filename (.+)$")
		if f then
			commit_file = f
			break
		end
	end

	if not commit_hash or not commit_file then
		vim.notify("Failed to extract commit info", vim.log.levels.ERROR)
		return
	end

	return {
		hash = commit_hash,
		line = tonumber(original_line),
		file = commit_file,
		file_hash = vim.fn.system("echo -n " .. vim.fn.shellescape(commit_file) .. " | sha256sum | cut -d' ' -f1"):gsub("\n",
			""),
	}
end

local function copy_git_link()
	local git_info = get_git_info()
	if not git_info then return end

	local start_line = vim.fn.line("v")
	local end_line = vim.fn.line(".")

	yank(string.format(
		"https://github.com/%s/blob/%s/%s#L%d-L%d",
		git_info.repo, git_info.branch, git_info.file, start_line, end_line
	))
end

local function copy_commit_url()
	local git_info = get_git_info()
	if not git_info then return end

	local blame = get_blame_info(git_info.file_dir, git_info.abs_path, vim.fn.line("."))
	if not blame then return end

	yank(string.format(
		"https://github.com/%s/commit/%s#diff-%sR%d",
		git_info.repo, blame.hash, blame.file_hash, blame.line
	))
end

-- Keymaps
vim.keymap.set("v", "<Leader>gy", copy_git_link, { desc = "Copy GitHub Link" })
vim.keymap.set("n", "<Leader>gC", copy_commit_url, { desc = "Copy Commit URL" })
vim.keymap.set('n', '<leader>go', '<cmd>DiffviewOpen<CR>', { desc = "Open Diff - Current" })
vim.keymap.set('n', '<leader>gO', '<cmd>DiffviewOpen origin/main...HEAD<CR>', { desc = "Open Diff - Main" })
vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory<CR>', { desc = "Diff History" })
vim.keymap.set('n', '<leader>gH', '<cmd>DiffviewFileHistory --range=origin..HEAD<CR>', { desc = "Diff History - Main" })
vim.keymap.set('n', '<leader>gc', '<cmd>DiffviewClose<CR>', { desc = "Close Diff" })
