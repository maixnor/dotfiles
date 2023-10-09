{ pkgs, lib, config, ...}:

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
			set undofile
			set termguicolors

			let mapleader = " "
			
			nnoremap <leader>e :Ex<cr>
			nnoremap <leader>g :Git<cr>
			nnoremap <leader>gp :Git push<cr>
			nnoremap <leader>gf :Git pull<cr>
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
