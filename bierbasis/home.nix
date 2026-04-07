{ config, lib, pkgs, inputs, ... }:

{
  
  imports = [
    inputs.stylix.homeModules.stylix
    inputs.agenix.homeManagerModules.default
    ../modules/minecraft.nix
    ../modules/tmux.nix
    ../modules/terminal.nix
    ../modules/zed.nix
    ../modules/office.nix
    ../modules/misc.nix
    ../modules/stylix.nix
    ../modules/zsh.nix
    ../modules/graphics.nix
    ../modules/firefox.nix
    ../modules/agentic.nix
  ];

  config = {
    home.username = "maixnor";
    home.homeDirectory = "/home/maixnor";

    home.file."justfile".text = ''
      update:
        cd ~/repo/dotfiles && just bierbasis
    '';

    services.kdeconnect = {
      enable = true;
    };

    home.stateVersion = "25.11";

    home.sessionVariables = {
      EDITOR = "nvim";
      LANG = "en_US.UTF-8";
      SSH_ASKPASS = "ksshaskpass";
    };

    programs.home-manager.enable = true;
    programs.kitty.settings = {
      font_size = lib.mkForce 13;
    };
    programs.git = {
      enable = true;
      settings = {
        user.name = "maixnor";
        user.email = "46966993+maixnor@users.noreply.github.com";
        pull.rebase = true;
        rebase.autoStash = true;
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        credential.helper = "${pkgs.gh}/bin/gh auth git-credential";
      };
    };

    services.ssh-agent.enable = true;
  };
}
