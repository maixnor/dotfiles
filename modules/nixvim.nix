{ config, lib, pkgs, ... }:

{

  programs.nixvim = {
    enable = true;
    enableMan = true;
    viAlias = true;
    vimAlias = true;

    # extraPackages = with pkgs; [ ripgrep parallel fd fzf bat fira-code-nerdfont ];

    opts = {
      number = true;         
      relativenumber = true; 

      shiftwidth = 2;        
      tabstop = 2;
      expandtab = true;
      autoindent = true;
      smartindent = true;

      undofile = true;
      termguicolors = true;
    };

    globals.mapleader = " ";

    #plugins.cmp.enable = true;
    #plugins.cmp.settings.mapping = {
    #  "<C-Space>" = "cmp.mapping.complete()";
    #  "<C-d>" = "cmp.mapping.scroll_docs(-4)";
    #  "<C-c>" = "cmp.mapping.close()";
    #  "<C-u>" = "cmp.mapping.scroll_docs(4)";
    #  "<CR>" = "cmp.mapping.confirm({ select = true })";
    #  "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
    #  "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
    #};

    plugins = {
      tmux-navigator.enable = true;
      lualine.enable = true;
      fugitive.enable = true;
      wakatime.enable = true;
      undotree.enable = true;
      nvim-colorizer.enable = true;
      treesitter.enable = true;
      treesitter-textobjects.enable = true;
      fzf-lua.enable = true;
      lsp.enable = true;
      lsp.servers = {
        nixd.enable = true;
      };
    };

    #plugins = {
    #  git-worktree.enable = true;
    #  git-conflict.enable = true;
    #  fzf-lua.profile = "fzf-vim";
      
      # lsp = {
      #   enable = true;
      #   servers = {
      #     nixd.enable = true;
      #     lua-ls.enable = true;
      #     omnisharp = {
      #       enable = true;
      #       settings.enableImportCompletion = true;
      #       settings.organizeImportsOnFormat = true;
      #     };
      #     java-language-server.enable = true;
      #     rust-analyzer = {
      #       enable = true;
      #       installCargo = false;
      #       installRustc = false;
      #     };
			# 		bashls.enable = true;
			# 		ts-ls.enable = true;

			# 		marksman.enable = true;
      #     ltex = {
      #       enable = true;
      #       settings = {
      #         enable = [ "latex" "markdown" "html" ];
      #         checkFrequency = "edit";
      #         language = "en-US";
      #         statusBarItem = true;
      #         completionEnabled = true;
      #         languageToolHttpServerUri = "http://127.0.0.1:6767/";
      #       };
      #     };

      #     html.enable = true;
      #     jsonls.enable = true;
      #     yamlls.enable = true;
      #   };
      # };
    #};

    highlightOverride = {
      Comment.fg = "#f47ac9";
      TreesitterContext.bg = "NONE";

      Normal.bg = "NONE";
      NonText.bg = "NONE";
      Normal.ctermbg = "NONE";
      NormalNC.bg = "NONE";
    };

    keymaps = [
      {
        action = "<cmd>FzfLua files<CR>";
        key = "<leader>ff";
      }
      {
        action = "<cmd>FzfLua live_grep_native<CR>";
        key = "<leader>fg";
      }
      {
        action = "<cmd>FzfLua diagnostics_document<CR>";
        key = "<leader>fd";
      }
      {
        action = "<cmd>FzfLua diagnostics_workspace<CR>";
        key = "<leader>fD";
      }
      {
        action = "<cmd>FzfLua quickfix<CR>";
        key = "<leader>fq";
      }
      {
        action = "<cmd>Git<CR>";
        key = "<leader>gs";
      }
      {
        action = "<cmd>Git push<CR>";
        key = "<leader>gp";
      }
      {
        action = "<cmd>Git pull<CR>";
        key = "<leader>gf";
      }
      {
        action = "<cmd>UndotreeShow<CR>";
        key = "<leader>u";
      }
    ];
  };
}
