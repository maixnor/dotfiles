{ pkgs, lib, config, ... }:

let
  custom = ./custom;
in 
{

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

	home.packages = with pkgs; [
		ripgrep
	];
  
	xdg.configFile."nvim" = {
    source = "${pkgs.vimPlugins.nvchad}";
    recursive = true;
  };

  xdg.configFile."nvim/lua" = {
    source = custom;
    recursive = true;
  };

}
