{ pkgs, config, ... }:

{

	home.packages = [
		pkgs.iosevka
    pkgs.fira-code
		pkgs.just
	];

	programs.alacritty = {
		enable = true;
		settings = {
			window = {
				opacity = 0.8;
				startup_mode = "Fullscreen";
				decorations = "full";
			};
			scrolling = {
				history = 30000;
			};
			font = {
				size = 16;
				normal = {
					family = "Fira Code";
				};
				bold = {
					family = "Fira Code";
					style = "Bold";
				};
				italic = {
					family = "Fira Code";
					style = "Italic";
				};
			};
			live_config_reload = true;
			shell = {
				program = "${pkgs.zsh}/bin/zsh";
			};
			colors = with config.colorScheme.palette; {
        draw_bold_text_with_bright_colors = true;
				cursor = {
					text = "#000000";
					cursor = "#ffffff";
				};
				selection = {
					background = "#${base04}";
					foreground = "#${base00}";
				};
				normal = {
					black = "#${base00}";
					white = "#${base05}";
					blue = "#${base0B}";
					cyan = "#${base07}";
					red = "#${base0A}";
					green = "#${base0D}";
				};
				primary = {
					background = "#${base00}";
					foreground = "#${base04}";
				};
			};	
		};
	};


}
