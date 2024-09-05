{ config, pkgs, ... }:

{

  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    bash.enable = true; # see note on other shells below
    # zsh enabled below, everything is fine 
  };

  programs.ripgrep.enable = true;
  programs.bat.enable = true;

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
    enableCompletion = true;
    shellAliases = {
			nix-shell = "export NIXPKGS_ALLOW_UNFREE=1 && nix-shell ";
      ping = "gping";
      ps = "procs";
      ls = "lsd";
      diff = "delta";
      cd = "z";
    };
  };

  programs.starship.enable = true;

	home.packages = with pkgs; [
    nix-zsh-completions

		fastfetch
    parallel
    wl-clipboard # wl-copy wl-paste

    bat fd ripgrep delta lsd dust duf # modern replacements
    choose sd cheat tldr gping procs dog # modern replacements

    clang coreutils just inotify-tools
		jq jc jo gron yj yq pup # like jq but different formats
	];

  home.file = {
    ".config/starship.toml".source = ../starship.toml;
  };


}
