{ config, lib, pkgs, nixvim, ... }:

{

  home.packages = with pkgs; [ ripgrep parallel ];

  programs.nixvim = {
    enable = true;

    options = {
      number = true;         
      relativenumber = true; 

      shiftwidth = 2;        
      tabstop = 2;
      undofile = true;
      termguicolors = true;
      autoindent = true;
      smartindent = true;
    };

    globals.mapleader = " ";

    colorschemes.oxocarbon.enable = true;

    plugins = {
      lualine.enable = true;
      telescope.enable = true;
      fugitive.enable = true;
      tmux-navigator.enable = true;
			luasnip.enable = true;
      treesitter.enable = true;
			treesitter-context.enable = true;
      treesitter-textobjects.enable = true;
      undotree.enable = true;
      nvim-colorizer.enable = true;
      lsp-format.enable = true;
			magma-nvim.enable = true;

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
      Comment.underline = true;
      Comment.bold = true;
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
				action = "<cmd>Telescope live_grep<CR>";
				key = "<leader>fg";
      }
      {
				action = "<cmd>Telescope find_files<CR>";
				key = "<leader>ff";
      }
      {
				action = "<cmd>Git<CR>";
				key = "<leader>g";
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
				action = "<cmd>lua vim.lsp.buf.formatting()<CR>";
				key = "<leader>a";
      }
      {
				action = "<cmd>UndoTreeShow<CR>";
				key = "<leader>u";
      }
    ];

    plugins.cmp = {
      enable = true;
      autoEnableSources = true;
    };
  };
}
