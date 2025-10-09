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
        HF_HOME = "/var/lib/immich/model-cache";
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
    # Declarative way to install extensions after database is created
    initialScript = pkgs.writeText "immich-init.sql" ''
      -- Create extensions for Immich
      \c immich;
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
      CREATE EXTENSION IF NOT EXISTS cube;
      CREATE EXTENSION IF NOT EXISTS earthdistance;
      CREATE EXTENSION IF NOT EXISTS vectors;
    '';
  };

  # Configure Redis server for Immich (separate from your languagebuddy instances)
  services.redis.servers.immich = {
    enable = true;
    port = 6390;
    bind = "localhost";
  };

  # Ensure the machine learning service has proper permissions
  systemd.services.immich-machine-learning = {
    serviceConfig = {
      # Ensure the service can write to the model cache
      ReadWritePaths = [ "/var/lib/immich/model-cache" ];
      # Give the service more time to download models on first run
      TimeoutStartSec = "10min";
    };
  };

  # Create Traefik configuration file for Immich
  environment.etc."traefik/immich.yml".text = ''
    http:
      routers:
        immich:
          rule: "Host(`photos.maixnor.com`)"
          service: "immich"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      services:
        immich:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:2283"
  '';

  # Create necessary directories and secrets file
  system.activationScripts.immich-setup = ''
    mkdir -p /var/lib/immich/{upload,model-cache}
    
    # Create secrets file with JWT secret if it doesn't exist
    if [ ! -f /var/lib/immich/secrets.env ]; then
      echo "JWT_SECRET=$(${pkgs.openssl}/bin/openssl rand -hex 32)" > /var/lib/immich/secrets.env
      chmod 600 /var/lib/immich/secrets.env
      chown immich:immich /var/lib/immich/secrets.env
    fi
    
    # Set proper ownership and permissions for directories
    chown -R immich:immich /var/lib/immich
    chmod -R 755 /var/lib/immich/model-cache
  '';
}
