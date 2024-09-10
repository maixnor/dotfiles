{ config, pkgs, inputs, ... }:

{
  
	imports = [
    inputs.nix-colors.homeManagerModules.default
    ../modules/tmux.nix
		../modules/terminal.nix
		../modules/office.nix
		../modules/misc.nix
		../modules/zsh.nix
		../modules/ollama.nix
		../modules/graphics.nix
    ../modules/firefox.nix
  ];

config = {
  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

  home.file."justfile".text = ''
    sync-wu-quartz:
      cd ~/repo/obsidian/submodules/wu-quartz/content && git add -p . && git commit -m "backup bierbasis" && git pull && git push && cd ~

    update:
      cd ~/repo/dotfiles && just bierzelt
  '';

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

  home.stateVersion = "24.05";

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
