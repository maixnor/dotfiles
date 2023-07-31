{ config, pkgs, ... }: 

{
  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";
  
  home.packages = with pkgs; [
    iosevka-comfy.comfy
    gh
    just
    neovim
    wget xh
    freshfetch
    spotify
    discord
    obsidian
  ]

  programs.git = {
    enable = true;
    userName = "Ryan Yin";
    userEmail = "xiaoyin_c@qq.com";
  };

  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        decorations: "None";
        startup_mode: "Maximized";
        opacity: 0.8;
      };
      font = {
        size = 10;
	draw_bold_text_with_bright_colors = true;
      };
      cursor = {
	style = "Block";
	unfocused_hollow: true;
      };
      shell = {
	program = "bash";
      };
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      f = "echo 'fffffffff ffffff'"
    };
  };

  home.stateVersion = "23.05";
  programs.home-manager.enable = true;
}
