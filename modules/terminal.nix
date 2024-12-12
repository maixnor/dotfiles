{ pkgs, config, ... }:

{

	home.packages = with pkgs; [
		just
    ranger
	];

	programs.alacritty = {
		enable = true;
		settings = {
			window = {
				startup_mode = "Fullscreen";
				decorations = "full";
			};
			scrolling = {
				history = 30000;
			};
			live_config_reload = true;
			shell = {
				program = "${pkgs.zsh}/bin/zsh";
			};
			colors = {
        draw_bold_text_with_bright_colors = true;
			};	
		};

	};


}
