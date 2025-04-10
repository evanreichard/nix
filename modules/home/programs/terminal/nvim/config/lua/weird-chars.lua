local ns = vim.api.nvim_create_namespace("weird-chars")

local weird_chars = {
	["–"] = "en dash found, consider using regular hyphen (-)",
	["—"] = "em dash found, consider using regular hyphen (-)",
	["“"] = 'left double quote found, consider using straight quote (")',
	["”"] = 'right double quote found, consider using straight quote (")',
	["‘"] = "left single quote found, consider using straight quote (')",
	["’"] = "right single quote found, consider using straight quote (')",
	["•"] = "bullet found, consider using regular asterisk (*)",
	["·"] = "middle dot found",
	["　"] = "full-width space found, consider using regular space",
}

local function check_weird_chars()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local diagnostics = {}

	for linenr, line in ipairs(lines) do
		local i = 1
		while i <= #line do
			local b = line:byte(i)
			local char

			-- Check for UTF-8 multi-byte sequences
			if b >= 0xE2 and b <= 0xEF then
				-- Likely a 3-byte UTF-8 sequence
				char = line:sub(i, i + 2)
				i = i + 3
			elseif b >= 0xC2 and b <= 0xDF then
				-- Likely a 2-byte UTF-8 sequence
				char = line:sub(i, i + 1)
				i = i + 2
			else
				-- Single byte character
				char = line:sub(i, i)
				i = i + 1
			end

			if weird_chars[char] then
				table.insert(diagnostics, {
					bufnr = bufnr,
					lnum = linenr - 1,
					col = i - #char - 1,
					message = weird_chars[char],
					severity = vim.diagnostic.severity.WARN,
				})
			end
		end
	end

	vim.diagnostic.set(ns, bufnr, diagnostics)
end

-- Create autocommand group
local group = vim.api.nvim_create_augroup("WeirdChars", { clear = true })

-- Set up autocommands
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "InsertLeave" }, {
	group = group,
	callback = check_weird_chars,
})

-- Create commands for manual checking
vim.api.nvim_create_user_command("CheckWeirdChars", check_weird_chars, {})
