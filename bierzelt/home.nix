{ config, pkgs, inputs, ... }:

{
  
	imports = [
    inputs.stylix.homeManagerModules.stylix
    inputs.nixvim.homeManagerModules.nixvim
    ../modules/nixvim.nix
    ../modules/tmux.nix
		../modules/terminal.nix
		../modules/office.nix
		../modules/misc.nix
		../modules/zsh.nix
		../modules/ollama.nix
		../modules/graphics.nix
    ../modules/firefox.nix
  ];

config = {
  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

  home.file."justfile".text = ''
    sync-wu-quartz:
      cd ~/repo/obsidian/submodules/wu-quartz/content && git add -p . && git commit -m "backup bierbasis" && git pull && git push && cd ~

    update:
      cd ~/repo/dotfiles && just bierzelt
  '';

  stylix = {
    enable = true;
    image = pkgs.fetchurl {
      url = "https://upload.wikimedia.org/wikipedia/commons/3/36/Golden_Horn_Metro_Bridge_Mars_2013.jpg";
      sha256 = "sha256-pcTdVAjM2cPJrwHdS61wvpH4pJJlTcE5LlDbJHe1Kno=";
    };
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/oxocarbon-dark.yaml";
    fonts = {
      monospace = {
        name = "Fira Code";
        package = pkgs.fira-code-nerdfont;
      };
      sizes = {
        desktop = 14;
        popups = 14;
        terminal = 12;
      };
    };
    opacity = {
      terminal = 0.8;
      desktop = 0.95;
      popups = 0.8;
    };
    targets.nixvim.transparentBackground.main = true;
    targets.nixvim.transparentBackground.signColumn = true;
  };

  services.kdeconnect = {
    enable = true;
    package = pkgs.kdePackages.kdeconnect-kde;
  };

  home.stateVersion = "24.11";

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
  };

  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userName = "maixnor";
    userEmail = "46966993+maixnor@users.noreply.github.com";
		extraConfig = {
			pull.rebase = true;
			rebase.autoStash = true;
			init.defaultBranch = "main";
			push.autoSetupRemote = true;
			credential.helper = "${pkgs.gh}/bin/gh auth git-credential";
    };
  };
};
}
