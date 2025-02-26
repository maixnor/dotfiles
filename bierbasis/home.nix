{ config, pkgs, inputs, ... }:

{

  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

  home.file."justfile".text = ''
    sync-wu-quartz:
      cd ~/repo/obsidian/submodules/wu-quartz/content && git add . && git commit -m "backup bierbasis" && git pull && git push && cd ~

    update:
      cd ~/repo/dotfiles && just bierbasis
  '';

  nixpkgs.config.allowUnfree = true;

  imports = [
    inputs.stylix.homeManagerModules.stylix
    inputs.nixvim.homeManagerModules.nixvim
    ../modules/tmux.nix
    ../modules/terminal.nix
    ../modules/office.nix
    ../modules/misc.nix
    #../modules/nixvim.nix
    ../modules/neovim.nix
    ../modules/zsh.nix
    ../modules/graphics.nix
    ../modules/firefox.nix
    ../modules/minecraft.nix
  ];

  home.stateVersion = "24.11";

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
  };

  stylix.fonts.sizes = {
    #application = 14;
    desktop = 14;
    popups = 14;
    terminal = 12;
  };

  services.kdeconnect = {
    enable = true;
    package = pkgs.kdePackages.kdeconnect-kde;
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
