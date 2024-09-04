{ config, pkgs, inputs, ... }:

{

  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

  nixpkgs.config.allowUnfree = true;

  imports = [
    inputs.stylix.homeManagerModules.stylix
    ../modules/tmux.nix
    ../modules/terminal.nix
    ../modules/office.nix
    ../modules/misc.nix
    ../modules/zsh.nix
    ../modules/ollama.nix
    ../modules/graphics.nix
    ../modules/firefox.nix
    ../modules/minecraft.nix
  ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.05";

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
  };

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
        package = pkgs.fira-code;
      };
      sizes = {
        desktop = 14;
        popups = 14;
        terminal = 16;
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

  # Let Home Manager install and manage itself.
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
}
