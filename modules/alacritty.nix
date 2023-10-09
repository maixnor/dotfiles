{ pkgs, config, ... }:

{

	programs.alacritty = {
		enable = true;
		settings = {
			window = {
				opacity = 0.9;
				startup_mode = "Fullscreen";
				decorations = "full";
			};
			scrolling = {
				history = 0;
			};
			font = {
				size = 12;
				normal = {
					family = "Iosevka Nerd Font";
				};
				bold = {
					family = "Iosevka Nerd Font";
					style = "Bold";
				};
				bold_italid = {
					family = "Iosevka Nerd Font";
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
				bright = {

				};
				cursor = {

				};
				selection = {

				};
				normal = {
					purple = "#${base00}";
					black = "#${base09}";
					pink = "#${base08}";
					red = "#${base07}";
					green = "#${base03}";
				};
				primary = {
					background = "#${base00}";
					foreground = "#${base05}";
				};
			};	
		};
	};


}
