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

			nnoremap <leader>ff <cmd>lua require('telescope.builtin').find_files()<cr>
			nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep()<cr>
			nnoremap <leader>fb <cmd>lua require('telescope.builtin').buffers()<cr>
			nnoremap <leader>fh <cmd>lua require('telescope.builtin').help_tags()<cr>

			highlight LineNrAbove guifg=#${config.colorScheme.palette.base03}
			highlight LineNr      guifg=#${config.colorScheme.palette.base04}
			highlight LineNrBelow guifg=#${config.colorScheme.palette.base03}
    '';
    plugins = with pkgs.vimPlugins; [
			plenary-nvim
      vim-fugitive
      vim-sensible
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
			telescope-nvim

      vim-tmux-clipboard
      vim-tmux-navigator
    ];
  };

	home.packages = with pkgs; [
		ripgrep
	];
}
