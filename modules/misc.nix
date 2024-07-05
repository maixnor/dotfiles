{ pkgs, config, ... }:

{

  config = {
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

      # kde
      kate
      okular
      spectacle
      kmail
      kdePackages.korganizer
      kdePackages.kontact
      kdePackages.kmail-account-wizard
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
      inotify-tools

      # unfree
      (writeShellApplication {
        name = "obsidian";
        text = "${obsidian}/bin/obsidian --disable-gpu";
      })
      (makeDesktopItem {
        name = "obsidian";
        exec = "obsidian";
        icon = "obsidian";
        desktopName = "Obsidian";
      })

      # KDE Kontact
      (makeDesktopItem {
        name = "Kontact";
        exec = "kontact";
        icon = "Kontact";
        desktopName = "Kontact";
      })

      # vivaldi unfree
      (writeShellApplication {
        name = "vivaldi";
        text = "${vivaldi}/bin/vivaldi --disable-features=AllowQt";
      })
      (makeDesktopItem {
        name = "vivaldi";
        exec = "vivaldi";
        icon = "vivaldi";
        desktopName = "Vivaldi";
      })

      # discord unfree
      (writeShellApplication {
        name = "discord";
        text = "${discord}/bin/discord --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-features=WaylandWindowDecorations";
      })
      (makeDesktopItem {
        name = "discord";
        exec = "discord";
        icon = "discord";
        desktopName = "Discord";
      })
    ];
  };

}
