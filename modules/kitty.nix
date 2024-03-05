{ config, lib, pkgs, ... }:

{
	programs.kitty = {
		enable = true;

		shellIntegration.enableZshIntegration = true;
		font.name = "Iosevka";
	};
}


