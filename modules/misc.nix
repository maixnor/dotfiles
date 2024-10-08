{ pkgs, config, ... }:

{

  config = {
    home.packages = with pkgs; [
      openconnect
      traceroute
      wget xh
      freshfetch
      spotify
      btop iftop iotop
      inotify-tools
      ripgrep-all
      # geogebra6
      # krita
      mpv
      anki
      nix-index

      # kde
      kate
      okular
      spectacle
      kdePackages.kmail
      kdePackages.korganizer
      kdePackages.kontact
      kdePackages.kmail-account-wizard
      kdePackages.plasma-disks
      konsole
      krusader
      kompare
      krename
      ktimetracker
      p7zip # ark dependency
      unrar # ark dependency

      # general development stuff
      gh
      vscodium
      # remmina
      # pandoc

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

      discord-canary

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
