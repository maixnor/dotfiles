{ pkgs, config, ... }:

{

  home.packages = with pkgs; [
    obsidian
		openconnect
		gh
		wget xh
		freshfetch
		spotify
		btop iftop iotop
		pandoc
		ripgrep-all
		geogebra6
		parallel
		direnv

		# kde
		kate
		okular
		spectacle
		kmail
		konsole
		krusader
		kompare
		krename

		# general development stuff
		vagrant
		fd clang coreutils just
		jq jc jo gron yj yq pup
		jetbrains.idea-community

		# unfree

    # discord
    (pkgs.writeShellApplication {
      name = "discord";
      text = "${pkgs.discord}/bin/discord --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-features=WaylandWindowDecorations";
    })
    (pkgs.makeDesktopItem {
      name = "discord";
      exec = "discord";
      desktopName = "Discord";
    })
  ];

}
