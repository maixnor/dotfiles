{ config, pkgs, lib, ... }:

{
  # Immich for photo management (Google Photos alternative)
  services.immich = {
    enable = true;
    port = 2283;
    host = "127.0.0.1";
    openFirewall = false; # We'll handle this via nginx
    mediaLocation = "/var/lib/immich/upload";
    
    # Database configuration - use socket connection for better security
    database = {
      enable = true;
      createDB = true;
      name = "immich";
      user = "immich";
      host = "/run/postgresql"; # Use Unix socket instead of TCP
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

  # Ensure PostgreSQL is configured properly for Immich
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "immich" ];
    ensureUsers = [
      {
        name = "immich";
        ensureDBOwnership = true;
      }
    ];
    # Add required PostgreSQL extensions for Immich
    extraPlugins = with config.services.postgresql.package.pkgs; [
      pg_vectors
    ];
  };

  # Configure Redis server for Immich (separate from your languagebuddy instances)
  services.redis.servers.immich = {
    enable = true;
    port = 6390;
    bind = "127.0.0.1";
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
      chown immich:immich /var/lib/immich/secrets.env
    fi
    
    # Set proper ownership for directories
    chown -R immich:immich /var/lib/immich
  '';
}
