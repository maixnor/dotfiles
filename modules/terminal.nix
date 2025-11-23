{ pkgs, lib, ... }:

{

	home.packages = with pkgs; [
		just
		ranger
	];

	programs.wezterm = {
		enable = true;
		enableZshIntegration = true;
		enableBashIntegration = true;
		extraConfig = builtins.readFile ./wezterm.lua;
	};

	programs.kitty = {
		enable = true;
		shellIntegration.enableZshIntegration = true;
		settings = {
			shell = "${pkgs.zsh}/bin/zsh -c 'tmux new-session -A -s kitty'";
		};
	};

	programs.alacritty = {
		enable = true;
		settings = {
			window = {
				startup_mode = "Windowed";
				decorations = "full";
			};
			scrolling = {
				history = 30000;
			};
			font.normal = lib.mkForce { family = "monospace"; };
			general.live_config_reload = true;
			terminal.shell = {
				program = "${pkgs.zsh}/bin/zsh";
				args = [ "-c" "tmux new-session -A -s alacritty" ];
			};
			colors = {
				draw_bold_text_with_bright_colors = true;
			};	
		};
	};

}
