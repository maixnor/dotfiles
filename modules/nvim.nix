{ pkgs, lib, nix-colors, ...}:

let
in

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    extraConfig = ''
      set number relativenumber
      set tabstop=2 shiftwidth=2
			set autoindent smartindent
    '';
    plugins = with pkgs.vimPlugins; [
      vim-fugitive
      vim-sensible
      nvim-lspconfig
      nvim-treesitter.withAllGrammars

      vim-tmux-clipboard
      vim-tmux-navigator
    ];
  };
}
