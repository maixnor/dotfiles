{ config, pkgs, lib, ... }:

{
  # Audiobookshelf for podcasts and audiobooks
  virtualisation.oci-containers.containers.audiobookshelf = {
    image = "ghcr.io/advplyr/audiobookshelf:latest";
    ports = [ "13378:80" ];
    volumes = [
      "/var/lib/audiobookshelf/config:/config"
      "/var/lib/audiobookshelf/metadata:/metadata"
      "/var/lib/audiobookshelf/podcasts:/podcasts"
      "/var/lib/audiobookshelf/audiobooks:/audiobooks"
    ];
    environment = {
      TZ = "Europe/Amsterdam";
    };
  };

  # Nginx configuration for Audiobookshelf
  services.nginx.virtualHosts."podcasts.maixnor.com" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:13378";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Allow large file uploads for audiobooks/podcasts
        client_max_body_size 2G;
      '';
    };
  };

  # Create necessary directories
  system.activationScripts.audiobookshelf-setup = ''
    mkdir -p /var/lib/audiobookshelf/{config,metadata,podcasts,audiobooks}
    # You can organize your content like this:
    # /var/lib/audiobookshelf/podcasts/ - for podcast episodes
    # /var/lib/audiobookshelf/audiobooks/ - for audiobook files
  '';
}
