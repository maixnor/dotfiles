{ pkgs, lib, ...}:

let
  # fromGitHub = ref: repo: pkgs.vimUtils.buildVimPlugin {
  #   pname = "${lib.strings.sanitizeDerivationName repo}";
  #   version = ref;
  #   src = builtins.fetchGit {
  #     url = "https://github.com/${repo}.git";
  #     ref = ref;
  #   };
  # };
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
      plenary-nvim
      mini-nvim
      # (fromGitHub "HEAD" "elihunter173/dirbuf.nvim")
    ];
  };
}
