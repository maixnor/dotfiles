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
    anki
    zerotierone

		# kde
		kate
		okular
		spectacle
		kmail
    libsForQt5.korganizer
    libsForQt5.kontact
    libsForQt5.kmail-account-wizard
		konsole
		krusader
		kompare
		krename
    ktimetracker
    p7zip # ark dependency
    unrar # ark dependency

		# general development stuff
    remmina
    vscodium
		jetbrains.idea-ultimate
    jetbrains.rider

		# unfree
    obsidian

    # KDE Kontact
    (pkgs.makeDesktopItem {
      name = "Kontact";
      exec = "kontact";
      icon = "Kontact";
      desktopName = "Kontact";
    })

    # vivaldi unfree
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

		# discord unfree
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
