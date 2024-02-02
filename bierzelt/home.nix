{ config, pkgs, inputs, ... }:

{
  
	imports = [
    inputs.nix-colors.homeManagerModules.default
    ../modules/shell.nix
    ../modules/tmux.nix
    ../modules/nvim.nix
		../modules/alacritty.nix
		../modules/kdeconnect.nix
		../modules/office.nix
		../modules/misc.nix
		../modules/zsh.nix
		../modules/ollama.nix
		../modules/graphics.nix
  ];

config = {
  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

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

  home.stateVersion = "23.11";

  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userName = "maixnor";
    userEmail = "46966993+maixnor@users.noreply.github.com";
		lfs.enable = true;
		extraConfig = {
			pull.rebase = true;
			rebase.autoStash = true;
			init.defaultBranch = "main";
			push.autoSetupRemote = true;
    };
  };
};
}
