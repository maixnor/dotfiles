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
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
    ];
  };
}
