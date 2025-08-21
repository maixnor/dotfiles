{ config, pkgs, lib, ... }:

{
  # Immich for photo management (Google Photos alternative)
  services.immich = {
    enable = true;
    port = 2283;
    host = "127.0.0.1";
    openFirewall = false; # We'll handle this via nginx
    mediaLocation = "/var/lib/immich/upload";
    
    # Database configuration
    database = {
      enable = true;
      createDB = true;
      name = "immich";
      user = "immich";
      host = "localhost";
      port = 5432;
    };
    
    # Redis configuration  
    redis = {
      enable = true;
      host = "localhost";
      port = 6390;
    };
    
    # Machine learning features
    machine-learning = {
      enable = true;
      environment = {
        TRANSFORMERS_CACHE = "/var/lib/immich/model-cache";
      };
    };
    
    # Immich settings
    settings = {
      server = {
        externalDomain = "https://photos.maixnor.com";
      };
      newVersionCheck = {
        enabled = false;
      };
    };
    
    # Environment variables
    environment = {
      LOG_LEVEL = "log";
    };
    
    # Secrets file for sensitive configuration like JWT_SECRET
    secretsFile = "/var/lib/immich/secrets.env";
  };

  # Nginx configuration for Immich
  services.nginx.virtualHosts."photos.maixnor.com" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:2283";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Allow large file uploads
        client_max_body_size 50000M;
      '';
    };
  };

  # Create necessary directories and secrets file
  system.activationScripts.immich-setup = ''
    mkdir -p /var/lib/immich/{upload,model-cache}
    
    # Create secrets file with JWT secret if it doesn't exist
    if [ ! -f /var/lib/immich/secrets.env ]; then
      echo "JWT_SECRET=$(${pkgs.openssl}/bin/openssl rand -hex 32)" > /var/lib/immich/secrets.env
      chmod 600 /var/lib/immich/secrets.env
    fi
    
    # Set proper ownership
    chown -R immich:immich /var/lib/immich
  '';
}
