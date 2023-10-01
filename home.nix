{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  home.packages = [
    pkgs.zoxide
  ];

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      # theme = "gruvbox";
    };
  };

  home.file = {
    ".local/share/zsh/nix-zsh-completions".source =
      "${pkgs.nix-zsh-completions}/share/zsh/plugins/nix";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userName = "maixnor";
    userEmail = "46966993+maixnor@users.noreply.github.com";
  };
}
