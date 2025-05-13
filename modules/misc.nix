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
      josm

      # nixos
      nix-index
      nixos-anywhere

      # kde
      kile
      krusader
      krename
      ktimetracker
      kdePackages.kompare
      kdePackages.konsole
      kdePackages.spectacle
      kdePackages.okular
      kdePackages.kate
      kdePackages.kmail
      kdePackages.kmailtransport
      kdePackages.mailimporter
      kdePackages.kdepim-addons
      kdePackages.kmail-account-wizard
      kdePackages.korganizer
      kdePackages.kontact
      kdePackages.plasma-disks

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
