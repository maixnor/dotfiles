{ pkgs, config, ... }:

{

    home.packages = with pkgs; [
        obsidian
				openconnect
				gh
				wget xh
				freshfetch
				spotify
				btop
				pandoc
				ripgrep
				geogebra6
				parallel

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
				direnv
				fd clang coreutils just
				jq jc jo gron yj yq pup

				# unfree

        # discord
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
