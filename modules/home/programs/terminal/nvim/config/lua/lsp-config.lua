------------------------------------------------------
------------------- Custom Settings ------------------
------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function()
		vim.bo.textwidth = 120
	end,
})

require('render-markdown').setup({
	completions = { lsp = { enabled = true } },
	file_types = { 'markdown', 'codecompanion' },
})

------------------------------------------------------
-------------------- Built-in LSP --------------------
------------------------------------------------------
local nix_vars = require("nix-vars")

local augroup = vim.api.nvim_create_augroup("LspFormatting", { clear = false })
local on_attach = function(client, bufnr)
	local bufopts = { noremap = true, silent = true, buffer = bufnr }

	if client:supports_method("textDocument/formatting") then
		vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
		vim.api.nvim_create_autocmd("BufWritePre", {
			group = augroup,
			buffer = bufnr,
			callback = function()
				vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
			end,
		})
	end

	vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
	vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, bufopts)
	vim.keymap.set("n", "<leader>lD", vim.lsp.buf.declaration, bufopts)
	vim.keymap.set("n", "<leader>ld", vim.lsp.buf.definition, bufopts)
	vim.keymap.set("n", "<leader>li", vim.lsp.buf.implementation, bufopts)
	vim.keymap.set("n", "<leader>ln", vim.lsp.buf.rename, bufopts)
	vim.keymap.set("n", "<leader>lr", vim.lsp.buf.references, bufopts)
	vim.keymap.set("n", "<leader>lt", vim.lsp.buf.type_definition, bufopts)
	vim.keymap.set("n", "<leader>lf", function()
		vim.lsp.buf.format({ async = true, timeout_ms = 2000 })
	end, bufopts)
end

local on_attach_no_formatting = function(client, bufnr)
	-- Disable Formatting
	client.server_capabilities.documentFormattingProvider = false
	client.server_capabilities.documentRangeFormattingProvider = false
	on_attach(client, bufnr)
end

local organize_go_imports = function()
	local encoding = vim.lsp.util._get_offset_encoding()
	local params = vim.lsp.util.make_range_params(nil, encoding)
	params.context = { only = { "source.organizeImports" } }

	local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
	for _, res in pairs(result or {}) do
		for _, r in pairs(res.result or {}) do
			if r.edit then
				vim.lsp.util.apply_workspace_edit(r.edit, encoding)
			else
				vim.lsp.buf.execute_command(r.command)
			end
		end
	end
end

local default_config = {
	flags = { debounce_text_changes = 150 },
	capabilities = require("cmp_nvim_lsp").default_capabilities(),
	on_attach = on_attach,
}
local setup_lsp = function(name, config)
	local final_config = vim.tbl_deep_extend("force", default_config, config or {})

	vim.lsp.config(name, final_config)
	vim.lsp.enable(name)
end

-- Python LSP Configuration
setup_lsp("pyright", {
	filetypes = { "starlark", "python" },
})

-- HTML LSP Configuration
setup_lsp("html", {
	on_attach = on_attach_no_formatting,
	cmd = { nix_vars.vscls .. "/bin/vscode-html-language-server", "--stdio" },
	filetypes = { "htm", "html" },
})

-- JSON LSP Configuration
setup_lsp("jsonls", {
	on_attach = on_attach_no_formatting,
	cmd = { nix_vars.vscls .. "/bin/vscode-html-language-server", "--stdio" },
	filetypes = { "json", "jsonc", "jsonl" },
})

-- CSS LSP Configuration
setup_lsp("cssls", {
	on_attach = on_attach_no_formatting,
	cmd = { nix_vars.vscls .. "/bin/vscode-html-language-server", "--stdio" },
	filetypes = { "css" },
})

-- Typescript / Javascript LSP Configuration
setup_lsp("ts_ls", {
	on_attach = on_attach_no_formatting,
	cmd = { nix_vars.tsls, "--stdio" },
	filetypes = { "typescript", "typescriptreact" },
})

-- C LSP Configuration
setup_lsp("clangd", {
	cmd = { nix_vars.clangd },
	filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
})

-- Lua LSP Configuration
setup_lsp("lua_ls", {
	cmd = { nix_vars.luals },
	filetypes = { "lua" },
})

-- Nix LSP Configuration
setup_lsp("nil_ls", {
	filetypes = { "nix" },
})

-- Omnisharp LSP Configuration
setup_lsp("omnisharp", {
	enable_roslyn_analyzers = true,
	enable_import_completion = true,
	organize_imports_on_format = true,
	enable_decompilation_support = true,
	filetypes = { "cs", "vb", "csproj", "sln", "slnx", "props", "csx", "targets", "tproj", "slngen", "fproj" },
	cmd = { nix_vars.omnisharp, "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
})

-- Go LSP Configuration
setup_lsp("gopls", {
	on_attach = function(client, bufnr)
		on_attach(client, bufnr)
		vim.api.nvim_create_autocmd("BufWritePre", {
			group = augroup,
			buffer = bufnr,
			callback = organize_go_imports,
		})
	end,
	cmd = { nix_vars.gopls },
	filetypes = { "go" },
	settings = {
		gopls = {
			buildFlags = { "-tags=e2e" },
		},
	},
})

-- Go LSP Linting
setup_lsp("golangci_lint_ls", {
	on_attach = on_attach_no_formatting,
	cmd = { nix_vars.golintls },
	filetypes = { "go" },
	init_options = {
		command = {
			"golangci-lint",
			"run",
			"--output.json.path",
			"stdout",
			"--show-stats=false",
			"--issues-exit-code=1",
		},
	},
})

------------------------------------------------------
--------------------- None-LS LSP --------------------
------------------------------------------------------
local none_ls = require("null-ls")

local eslintFiles = {
	".eslintrc",
	".eslintrc.js",
	".eslintrc.cjs",
	".eslintrc.yaml",
	".eslintrc.yml",
	".eslintrc.json",
	"eslint.config.js",
	"eslint.config.mjs",
	"eslint.config.cjs",
	"eslint.config.ts",
	"eslint.config.mts",
	"eslint.config.cts",
}

local has_eslint_in_parents = function(fname)
	local root_file = require("lspconfig").util.insert_package_json(eslintFiles, "eslintConfig", fname)
	return require("lspconfig").util.root_pattern(unpack(root_file))(fname)
end

none_ls.setup({
	sources = {
		-- Prettier Formatting
		none_ls.builtins.formatting.prettier,
		none_ls.builtins.formatting.prettier.with({ filetypes = { "template" } }),
		require("none-ls.diagnostics.eslint_d").with({
			condition = function(utils)
				return has_eslint_in_parents(vim.fn.getcwd())
			end,
		}),
		none_ls.builtins.completion.spell,
		none_ls.builtins.formatting.nixpkgs_fmt, -- TODO: nixd native LSP?
		none_ls.builtins.diagnostics.sqlfluff,
		none_ls.builtins.formatting.sqlfluff,
		require("none-ls.formatting.autopep8").with({
			filetypes = { "starlark", "python" },
			extra_args = { "--max-line-length", "100" },
		}),
	},
	on_attach = function(client, bufnr)
		if client:supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
				end,
			})
		end
	end,
})
