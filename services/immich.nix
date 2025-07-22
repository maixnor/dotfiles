{ config, pkgs, lib, ... }:

{
  # Immich for photo management (Google Photos alternative)
  virtualisation.oci-containers.containers.immich-server = {
    image = "ghcr.io/immich-app/immich-server:release";
    ports = [ "2283:3001" ];
    environment = {
      DB_HOSTNAME = "immich-postgres";
      DB_USERNAME = "postgres";
      DB_PASSWORD = "postgres";
      DB_DATABASE_NAME = "immich";
      REDIS_HOSTNAME = "immich-redis";
      LOG_LEVEL = "log";
      JWT_SECRET = "randomjwtsecret123";
    };
    volumes = [
      "/var/lib/immich/upload:/usr/src/app/upload"
      "/etc/localtime:/etc/localtime:ro"
    ];
    dependsOn = [ "immich-postgres" "immich-redis" ];
  };

  virtualisation.oci-containers.containers.immich-machine-learning = {
    image = "ghcr.io/immich-app/immich-machine-learning:release";
    volumes = [
      "/var/lib/immich/model-cache:/cache"
    ];
    environment = {
      TRANSFORMERS_CACHE = "/cache";
    };
  };

  virtualisation.oci-containers.containers.immich-postgres = {
    image = "tensorchord/pgvecto-rs:pg14-v0.2.0";
    environment = {
      POSTGRES_PASSWORD = "postgres";
      POSTGRES_USER = "postgres";
      POSTGRES_DB = "immich";
      POSTGRES_INITDB_ARGS = "--data-checksums";
    };
    volumes = [
      "/var/lib/immich/postgres:/var/lib/postgresql/data"
    ];
  };

  virtualisation.oci-containers.containers.immich-redis = {
    image = "redis:6.2-alpine";
    volumes = [
      "/var/lib/immich/redis:/data"
    ];
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

  # Create necessary directories
  system.activationScripts.immich-setup = ''
    mkdir -p /var/lib/immich/{upload,postgres,redis,model-cache}
    chown -R 999:999 /var/lib/immich/postgres
    chown -R 999:999 /var/lib/immich/redis
  '';
}
