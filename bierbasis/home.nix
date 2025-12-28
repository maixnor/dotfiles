{ config, lib, pkgs, inputs, ... }:

{
  
  imports = [
    inputs.stylix.homeModules.stylix
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
    ../modules/gemini.nix
  ];

  config = {
    nixpkgs.config.allowUnfree = true;
    home.username = "maixnor";
    home.homeDirectory = "/home/maixnor";

    home.file."justfile".text = ''
      sync-wu-quartz:
        cd ~/repo/obsidian/submodules/wu-quartz/content && git add . && git commit -m "backup bierbasis" && git pull && git push && cd ~

      update:
        cd ~/repo/dotfiles && just bierbasis
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
  };
}