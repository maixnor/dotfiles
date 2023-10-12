{ pkgs, config, ... }:

{

	home.packages = [
		pkgs.iosevka
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
				history = 0;
			};
			font = {
				size = 8;
				normal = {
					family = "Iosevka";
				};
				bold = {
					family = "Iosevka";
					style = "Bold";
				};
				bold_italid = {
					family = "Iosevka";
					style = "Bold Italic";
				};
				italic = {
					family = "Iosevka Nerd Font";
					style = "Italic";
				};
			};
			draw_bold_text_with_bright_colors = true;
			live_config_reload = true;
			save_to_clipboard = true;
			shell = {
				program = "${pkgs.zsh}/bin/zsh";
			};
			colors = with config.colorScheme.colors; {
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
					purple = "#${base0E}";
					pink = "#${base0C}";
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