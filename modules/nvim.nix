{ pkgs, lib, ...}:

let
in

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = with pkgs.vimPlugins; [
      vim-fugitive
      vim-sensible
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
    ];
  };
}
