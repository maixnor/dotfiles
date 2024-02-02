{ pkgs, config, ... }:

{

	programs.zsh = {
		enable = true;
		enableCompletion = true;

    shellAliases = {
			ll = "ls -l";
			update = "sudo nixos-rebuild switch";
			nix-shell = "export NIXPKGS_ALLOW_UNFREE=1 && nix-shell ";
		};
	};
}
