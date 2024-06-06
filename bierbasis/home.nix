{ config, pkgs, inputs, ... }:

{

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

  nixpkgs.config.allowUnfree = true;

  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.nixvim.homeManagerModules.nixvim
    inputs.stylix.homeManagerModules.stylix
    ../modules/tmux.nix
    ../modules/nixvim.nix
    ../modules/alacritty.nix
    ../modules/kdeconnect.nix
    ../modules/office.nix
    ../modules/misc.nix
    ../modules/zsh.nix
    ../modules/ollama.nix
    ../modules/graphics.nix
    ../modules/firefox.nix
  ];

	colorScheme = {
    slug = "oxocarbon";
    name = "Oxocarbon Dark";
    author = "shaunsingh/IBM";
    palette = {
      base00 = "#161616";
      base01 = "#262626";
      base02 = "#393939";
      base03 = "#525252";
      base04 = "#dde1e6";
      base05 = "#f2f4f8";
      base06 = "#ffffff";
      base07 = "#08bdba";
      base08 = "#3ddbd9";
      base09 = "#78a9ff";
      base0A = "#ee5396";
      base0B = "#33b1ff";
      base0C = "#ff7eb6";
      base0D = "#42be65";
      base0E = "#be95ff";
      base0F = "#82cfff";
    };
  }; 

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.11";

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
  };

  stylix = {
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
        desktop = 12;
        terminal = 16;
      };
    };
    opacity = {
      terminal = 0.8;
    };
    targets.gnome.enable = false;
    targets.gtk.enable = false;
    targets.kde.enable = false;
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
