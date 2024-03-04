{ config, pkgs, ... }:

{

  programs.ripgrep.enable = true;
  programs.bat.enable = true;
	programs.bat.config.theme = "Dracula";
  programs.translate-shell.enable = true;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    shellAliases = {
    };
  };

  programs.starship.enable = true;

	home.packages = [
		pkgs.neofetch
		pkgs.fd
	];

  home.file = {
    ".config/starship.toml".source = ../starship.toml;
  };


}
