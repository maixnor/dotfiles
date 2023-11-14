{ pkgs, config, ... }:

{

	home.packages = with pkgs; [
		nix-zsh-completions
		zsh-nix-shell
		zsh-you-should-use
	];

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
