
{ config, lib, pkgs, inputs, ... }:

{
  
  imports = [
    inputs.stylix.homeModules.stylix
    ../modules/tmux.nix
    ../modules/terminal.nix
    ../modules/office.nix
    ../modules/misc.nix
    ../modules/stylix.nix
    ../modules/zsh.nix
    ../modules/graphics.nix
    ../modules/librewolf.nix
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
    stylix.targets = {
      gnome.enable = lib.mkForce true;
      gtk.enable = lib.mkForce true;
      kde.enable = lib.mkForce true;
    };
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
    qt = lib.mkForce {
      enable = true;
      style.name = "breeze";
      platformTheme.name = "kde";
    };

    services.kdeconnect = {
      enable = true;
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
