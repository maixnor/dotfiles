{ pkgs, config, ... }:

{
  config = {


    home.packages = with pkgs; [
      psmisc lsof
      openconnect
      traceroute
      wget xh
      freshfetch
      presenterm
      calc
      miraclecast
      iftop iotop
      inotify-tools
      ripgrep-all
      # geogebra6
      # krita
      inkscape
      mpv
      anki
      ngrok
      josm
      nextcloud-client
      insync
      ffmpeg_8-headless
      mdcat
      nh

      # nixos
      nix-index
      nixos-anywhere

      # kde
      kile
      krusader
      krename
      ktimetracker
      kdePackages.kompare
      kdePackages.ktorrent
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
      vscodium
      chromium
      static-server
      # remmina
      # pandoc

      # unfree
      obsidian
      discord
      anydesk
      signal-desktop

      # slack-term
      slack-term
      (pkgs.writeShellScriptBin "slack" ''
        exec ${pkgs.slack-term}/bin/slack-term -config "/run/agenix/slack_term" "$@"
      '')
    ];

    programs.btop.enable = true;
  };

}
