
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
      update:
        cd ~/repo/dotfiles && just bierzelt
    '';

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
