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

      # nixos
      nix-index
      nixos-anywhere

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

      ### KDE Kontact
      (makeDesktopItem {
        name = "Kontact";
        exec = "kontact";
        icon = "Kontact";
        desktopName = "Kontact";
      })

      # general development stuff
      gh
      vscodium
      chromium
      # remmina
      # pandoc

      # unfree
      obsidian
      discord-canary
      discord
    ];
  };

}
