{ pkgs, nix-colors, ... }:

{
	import = [
    nix-colors.homeManagerModules.default
		./modules/alacritty.nix
  ];

	colorScheme = nix-colors.colorSchemes.dracula;

}
