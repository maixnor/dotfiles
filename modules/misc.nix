{ pkgs, config, ... }:

{

  config = {
    home.packages = with pkgs; [
      openconnect
      traceroute
      wget xh
      freshfetch
      calc
      spotify
      btop iftop iotop
      inotify-tools
      ripgrep-all
      # geogebra6
      # krita
      inkscape
      mpv
      anki
      thunderbird
      ngrok

      # nixos
      nix-index
      nixos-anywhere

      # kde
      kile
      kate
      okular
      spectacle
      kdePackages.kmail
      kdePackages.kmailtransport
      kdePackages.kdepim-addons
      kdePackages.kmail-account-wizard
      kdePackages.korganizer
      kdePackages.kontact
      kdePackages.plasma-disks
      konsole
      krusader
      kompare
      krename
      ktimetracker
      quota
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
      static-server
      # remmina
      # pandoc

      # unfree
      obsidian
      discord-canary
      discord
    ];
  };

}
