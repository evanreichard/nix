{ pkgs
, lib
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.nvim;
in
{
  options.${namespace}.programs.terminal.nvim = {
    enable = lib.mkEnableOption "NeoVim";
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      withNodeJs = true;
      withPython3 = true;

      plugins = with pkgs.vimPlugins; [
        # ------------------
        # --- Completion ---
        # ------------------
        cmp-buffer # Buffer Word Completion
        cmp-cmdline # Command Line Completion
        cmp-nvim-lsp # Main LSP
        cmp-path # Path Completion
        cmp_luasnip # Snippets Completion
        friendly-snippets # Snippets
        lsp_lines-nvim # Inline Diagnostics
        luasnip # Snippets
        nvim-cmp # Completions
        nvim-lspconfig # LSP Config

        # -------------------
        # ----- Helpers -----
        # -------------------
        comment-nvim # Code Comments
        copilot-vim # GitHub Copilot
        diffview-nvim # Diff View
        fidget-nvim # Notification Helper
        gitsigns-nvim # Git Blame
        leap-nvim # Quick Movement
        markdown-preview-nvim # Markdown Preview
        none-ls-nvim # Formatters
        numb-nvim # Peek / Jump to Lines
        nvim-autopairs # Automatically Close Pairs (),[],{}
        octo-nvim # Git Octo
        render-markdown-nvim # Markdown Renderer
        snacks-nvim # Snacks
        telescope-nvim # Fuzzy Finder
        vim-nix # Nix Helpers
        which-key-nvim # Shortcut Helper

        # ------------------
        # --- Theme / UI ---
        # ------------------
        catppuccin-nvim # Theme
        lualine-nvim # Bottom Line
        noice-nvim # UI Tweaks
        nvim-notify # Noice Dependency
        nvim-web-devicons # Dev Icons

        # ------------------
        # --- Treesitter ---
        # ------------------
        nvim-treesitter-context
        nvim-treesitter.withAllGrammars

        # -------------------
        # ------- DAP -------
        # -------------------
        nvim-dap
        nvim-dap-go
        nvim-dap-ui

        # --------------------
        # -- CODE COMPANION --
        # --------------------
        (pkgs.vimUtils.buildVimPlugin {
          pname = "codecompanion.nvim";
          version = "2025-12-20";
          src = pkgs.fetchFromGitHub {
            owner = "olimorris";
            repo = "codecompanion.nvim";
            rev = "a226ca071ebc1d8b5ae1f70800fa9cf4a06a2101";
            sha256 = "sha256-F1nI7q98SPpDjlwPvGy/qFuHvlT1FrbQPcjWrBwLaHU=";
          };
          doCheck = false;
          meta.homepage = "https://github.com/olimorris/codecompanion.nvim/";
          meta.hydraPlatforms = [ ];
        })

        # --------------------
        # -- NONE-LS EXTRAS --
        # --------------------
        (pkgs.vimUtils.buildVimPlugin {
          pname = "none-ls-extras.nvim";
          version = "2025-10-28";
          src = pkgs.fetchFromGitHub {
            owner = "nvimtools";
            repo = "none-ls-extras.nvim";
            rev = "402c6b5c29f0ab57fac924b863709f37f55dc298";
            sha256 = "sha256-4s/xQNWNA4dgb5gZR4Xqn6zDDWrSJNtmHOmmjmYnN/8=";
          };
          doCheck = false;
          meta.homepage = "https://github.com/nvimtools/none-ls-extras.nvim/";
        })

        # -------------------
        # ---- LLAMA.VIM ----
        # -------------------
        (pkgs.vimUtils.buildVimPlugin {
          pname = "llama.vim";
          version = "2025-10-28";
          src = pkgs.fetchFromGitHub {
            owner = "ggml-org";
            repo = "llama.vim";
            rev = "ade8966eff57dcbe4a359dd26fb1ea97378ea03c";
            sha256 = "sha256-uPqOZLWKVMimhc9eG7yM5OmhJy3mTRgKsiqKhstWs4Y=";
          };
          meta.homepage = "https://github.com/ggml-org/llama.vim/";
        })
      ];

      extraPackages = with pkgs; [
        # LSP
        eslint_d
        go
        golangci-lint
        golangci-lint-langserver
        gopls
        lua-language-server
        nil
        nodePackages.eslint
        nodePackages.svelte-language-server
        nodePackages.typescript
        nodePackages.typescript-language-server
        nodePackages.vscode-langservers-extracted
        pyright
        python312Packages.autopep8

        # Formatters
        luaformatter
        nixpkgs-fmt
        nodePackages.prettier
        sqlfluff
        stylua

        # Tools
        ripgrep
        lazygit
      ];

      extraConfig = ":luafile ~/.config/nvim/lua/init.lua";
    };

    xdg.configFile = {
      # Copy Configuration
      nvim = {
        source = ./config;
        recursive = true;
      };

      # Generate Nix Vars
      "nvim/lua/nix-vars.lua".text = ''
        local nix_vars = {
          bash = "${pkgs.bashInteractive}/bin/bash",
          clangd = "${pkgs.clang-tools}/bin/clangd",
          golintls = "${pkgs.golangci-lint-langserver}/bin/golangci-lint-langserver",
          gopls = "${pkgs.gopls}/bin/gopls",
          luals = "${pkgs.lua-language-server}/bin/lua-language-server",
          omnisharp = "${pkgs.omnisharp-roslyn}/bin/OmniSharp",
          sveltels = "${pkgs.nodePackages.svelte-language-server}/bin/svelteserver",
          tsls = "${pkgs.nodePackages.typescript-language-server}/bin/typescript-language-server",
          vscls = "${pkgs.nodePackages.vscode-langservers-extracted}",
        }
        return nix_vars
      '';
    };
  };
}
