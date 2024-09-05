
{ config, pkgs, inputs, ... }:

{

  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

  nixpkgs.config.allowUnfree = true;

  imports = [
    inputs.stylix.homeManagerModules.stylix
    ../modules/tmux.nix
    ../modules/misc-server.nix
  ];

  home.stateVersion = "24.05";

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
  };

  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
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
