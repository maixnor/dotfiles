{ config, lib, pkgs, nixvim, ... }:

{

  programs.nixvim = {
    enable = true;
		enableMan = true;
    viAlias = true;
    vimAlias = true;

		extraPackages = with pkgs; [ ripgrep parallel fd fzf ];

		clipboard.providers.wl-copy.enable = true;

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

    colorschemes.oxocarbon.enable = true;

    plugins = {
      lualine.enable = true;
      fugitive.enable = true;
      tmux-navigator.enable = true;
      treesitter.enable = true;
			treesitter-context.enable = true;
      treesitter-textobjects.enable = true;
      undotree.enable = true;
      nvim-colorizer.enable = true;
      fzf-lua.enable = true;

      lsp = {
				enable = true;
				servers = {
					lua-ls.enable = true;
					rust-analyzer.enable = true;
					bashls.enable = true;
					tsserver.enable = true;
					marksman.enable = true;

					html.enable = true;
					jsonls.enable = true;
					yamlls.enable = true;
				};
      };
    };

    plugins.lsp.servers.rust-analyzer.installCargo = true;
    plugins.lsp.servers.rust-analyzer.installRustc = true;

    highlight = {
      Comment.fg = "#f47ac9";

      Normal.bg = "NONE";
      NonText.bg = "NONE";
			Normal.ctermbg = "NONE";
			NormalNC.bg = "NONE";

      LineNrAbove.fg="#${config.colorScheme.palette.base03}";
      LineNr.fg="#${config.colorScheme.palette.base04}";
      LineNrBelow.fg="#${config.colorScheme.palette.base03}";
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

    plugins.cmp = {
      enable = true;
      autoEnableSources = true;
    };
    plugins.cmp-nvim-lsp.enable = true;
  };
}
