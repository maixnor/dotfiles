{ pkgs, config, ... }:

{

	programs.alacritty = {
		enable = true;
		settings = {
			colors = with config.colorScheme.colors; {
				bright = {

				};
				cursor = {

				};
				normal = {

				};
				primary = {
					background = "0x${base00}";
				};
			};	
		};
	};


}
