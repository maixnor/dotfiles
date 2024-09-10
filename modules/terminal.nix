{ pkgs, config, ... }:

{

	home.packages = [
    pkgs.fira-code
		pkgs.just
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
				program = "${pkgs.tmux}/bin/tmux";
			};
			colors = {
        draw_bold_text_with_bright_colors = true;
			};	
		};

	};


}
