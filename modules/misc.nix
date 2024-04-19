{ pkgs, config, ... }:

{

  home.packages = with pkgs; [
		openconnect
    traceroute
		gh
		wget xh
		freshfetch
		spotify
		btop iftop iotop
		pandoc
		ripgrep-all
		geogebra6
		krita
    mpv

		# kde
		kate
		okular
		spectacle
		kmail
		konsole
		krusader
		kompare
		krename
    kdePackages.krdc # RDP client
    p7zip # ark dependency
    unrar # ark dependency

		# general development stuff
    vscodium
		jetbrains.idea-community
    jetbrains.rider

		# unfree
    obsidian
    # vivaldi
    (pkgs.writeShellApplication {
      name = "vivaldi";
      text = "${pkgs.vivaldi}/bin/vivaldi --disable-features=AllowQt";
    })
    (pkgs.makeDesktopItem {
      name = "vivaldi";
      exec = "vivaldi";
      icon = "vivaldi";
      desktopName = "Vivaldi";
    })

		# discord
    (pkgs.writeShellApplication {
      name = "discord";
      text = "${pkgs.discord}/bin/discord --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-features=WaylandWindowDecorations";
    })
    (pkgs.makeDesktopItem {
      name = "discord";
      exec = "discord";
			icon = "discord";
      desktopName = "Discord";
    })
  ];

}
