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

  # Nginx configuration for Navidrome
  services.nginx.virtualHosts."music.maixnor.com" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:4533";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Increase timeout for music streaming
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
      '';
    };
  };

  # Create necessary directories
  system.activationScripts.navidrome-setup = ''
    mkdir -p /var/lib/navidrome/{data,music}
    # You can organize your music in /var/lib/navidrome/music/
    # Structure example:
    # /var/lib/navidrome/music/Artist Name/Album Name/Track.mp3
  '';
}
