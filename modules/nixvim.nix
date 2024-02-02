{ config, lib, pkgs, nixvim, ... }:

{
  programs.nixvim = {
    enable = true;

      options = {
    number = true;         # Show line numbers
    relativenumber = true; # Show relative line numbers

    shiftwidth = 2;        # Tab width should be 2
  };

    globals.mapleader = " ";

    colorschemes.oxocarbon.enable = true;

    plugins = {
      lualine.enable = true;
      bufferline.enable = true;
      fugitive.enable = true;
      luasnip.enable = true;
      telescope.enable = true;
      tmux-navigator.enable = true;
      treesitter.enable = true;
      treesitter-textobjects.enable = true;
      undotree.enable = true;

      lsp = {
    enable = true;
    servers = {
      lua-ls.enable = true;
      rust-analyzer.enable = true;
      nixd.enable = true;
    };
      };
    };

    plugins.lsp.servers.rust-analyzer.installCargo = false;
    plugins.lsp.servers.rust-analyzer.installRustc = false;

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
      key = "<leader>gp";
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
      action = "<cmd>UndoTreeShow<CR>";
      key = "<leader>u";
    }
  ];

    plugins.nvim-cmp = {
      enable = true;
      autoEnableSources = true;
      sources = [
        {name = "nvim_lsp";}
        {name = "path";}
        {name = "buffer";}
        {name = "luasnip";}
      ];

      mapping = {
        "<CR>" = "cmp.mapping.confirm({ select = true })";
        "<Tab>" = {
          action = ''
            function(fallback)
              if cmp.visible() then
                cmp.select_next_item()
              elseif luasnip.expandable() then
                luasnip.expand()
              elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
              elseif check_backspace() then
                fallback()
              else
                fallback()
              end
            end
          '';
          modes = [ "i" "s" ];
        };
      };
    };
  };
}
