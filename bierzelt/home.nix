
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
    ../modules/graphics.nix
    ../modules/firefox.nix
    ../modules/myzaney/home.nix
  ];

  config = {
    nixpkgs.config.allowUnfree = true;
    home.username = "maixnor";
    home.homeDirectory = "/home/maixnor";

    home.file."justfile".text = ''
      sync-wu-quartz:
        cd ~/repo/obsidian/submodules/wu-quartz/content && git add . && git commit -m "backup bierbasis" && git pull && git push && cd ~

      update:
        cd ~/repo/dotfiles && just bierzelt
    '';

    # Styling Options
    gtk = {
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };
    qt = {
      enable = true;
      style.name = "adwaita-dark";
      platformTheme.name = "gtk3";
    };
    stylix = {
      image = pkgs.fetchurl {
        url = "https://upload.wikimedia.org/wikipedia/commons/3/36/Golden_Horn_Metro_Bridge_Mars_2013.jpg";
        sha256 = "sha256-pcTdVAjM2cPJrwHdS61wvpH4pJJlTcE5LlDbJHe1Kno=";
      };
      #base16Scheme = "${pkgs.base16-schemes}/share/themes/oxocarbon-dark.yaml";
      polarity = "dark";
      fonts = {
        monospace = {
          package = pkgs.nerdfonts.override { fonts = [ "Iosevka" ]; };
          name = "Iosevka";
        };
        sansSerif = {
          package = pkgs.montserrat;
          name = "Montserrat";
        };
        serif = {
          package = pkgs.montserrat;
          name = "Montserrat";
        };
        sizes = {
          applications = 12;
          terminal = 15;
          popups = 12;
        };
      };
      targets = {
        waybar.enable = false;
        rofi.enable = false;
        hyprland.enable = false;
        nixvim.transparentBackground.main = true;
        nixvim.transparentBackground.signColumn = true;
      };
      cursor.package = pkgs.bibata-cursors;
      cursor.name = "Bibata-Modern-Ice";
      cursor.size = 24;
      opacity = {
        terminal = 0.8;
        desktop = 0.95;
        popups = 0.8;
      };
    };

    services.kdeconnect = {
      enable = true;
      package = pkgs.kdePackages.kdeconnect-kde.overrideAttrs (oldAttrs: {
        buildInputs = (oldAttrs.buildInputs or []) ++ [ pkgs.kdePackages.qtconnectivity ];
        cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [ "-DBLUETOOTH_ENABLED=ON" ];
      });

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
