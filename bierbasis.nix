{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

  targets.genericLinux.enable = true;
  nixpkgs.config.allowUnfree = true;

  imports = [
		./colors.nix
    ./modules/shell.nix
    ./modules/tmux.nix
    ./modules/nvim.nix
		./modules/alacritty.nix
  ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
  };

  home.packages = [
    pkgs.zoxide
  ];

  home.file = {
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userName = "maixnor";
    userEmail = "46966993+maixnor@users.noreply.github.com";
  };
}
