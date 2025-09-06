{ config, pkgs, lib, ... }:

{
  # Navidrome for music streaming (Spotify alternative for your music collection)
  virtualisation.oci-containers.containers.navidrome = {
    image = "deluan/navidrome:latest";
    ports = [ "4533:4533" ];
    volumes = [
      "/var/lib/navidrome/data:/data"
      "/var/lib/navidrome/music:/music:ro"
    ];
    environment = {
      ND_MUSICFOLDER = "/music";
      ND_DATAFOLDER = "/data";
      ND_ENABLETRANSCODINGCONFIG = "true";
      ND_LOGLEVEL = "info";
      ND_SESSIONTIMEOUT = "24h";
      ND_BASEURL = "";
      # Scanning options
      ND_SCANSCHEDULE = "@every 1h";
      ND_ENABLESTARRATING = "true";
      ND_ENABLEFAVOURITES = "true";
      ND_ENABLEDOWNLOADS = "true";
      # Transcoding
      ND_TRANSCODINGCACHESIZE = "100MB";
      ND_IMAGECACHESIZE = "100MB";
    };
  };

  # Create Traefik configuration file for Navidrome
  environment.etc."traefik/navidrome.yml".text = ''
    http:
      routers:
        navidrome:
          rule: "Host(`music.maixnor.com`)"
          service: "navidrome"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      services:
        navidrome:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:4533"
  '';

  # Create necessary directories
  system.activationScripts.navidrome-setup = ''
    mkdir -p /var/lib/navidrome/{data,music}
    # You can organize your music in /var/lib/navidrome/music/
    # Structure example:
    # /var/lib/navidrome/music/Artist Name/Album Name/Track.mp3
  '';
}
