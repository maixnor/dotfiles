{ config, pkgs, lib, ... }:

{
  services.nextcloud = {
    enable = true;
    hostName = "cloud.maixnor.com";
    
    package = pkgs.nextcloud31;
    
    # Use HTTPS
    https = true;
    
    # Admin configuration
    config = {
      dbtype = "pgsql";
      dbuser = "nextcloud";
      dbhost = "/run/postgresql";
      dbname = "nextcloud";
      adminpassFile = "/var/lib/nextcloud/admin-pass";
      adminuser = "admin";
    };
    
    # Configure Redis for better performance
    configureRedis = true;
    
    # Database configuration
    database.createLocally = true;
    
    # Auto-update apps
    autoUpdateApps.enable = true;
    autoUpdateApps.startAt = "05:00:00";
    
    # Additional settings for better performance
    settings = {
      overwriteprotocol = "https";
      default_phone_region = "AT";
      
      # Memory and performance settings
      "memcache.local" = "\\OC\\Memcache\\APCu";
      "memcache.distributed" = "\\OC\\Memcache\\Redis";
      "memcache.locking" = "\\OC\\Memcache\\Redis";
      
      # File settings
      "max_filesize_animated_gifs_public_sharing" = 10;
      "preview_max_x" = 2048;
      "preview_max_y" = 2048;
      "jpeg_quality" = 60;
    };
    
    # PHP settings
    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
      "opcache.max_accelerated_files" = "10000";
      "opcache.memory_consumption" = "128";
      "opcache.revalidate_freq" = "1";
      "opcache.fast_shutdown" = "1";
    };
  };

  # Nginx configuration for Nextcloud
  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    forceSSL = true;
    enableACME = true;
    
    # Security headers
    extraConfig = ''
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header Referrer-Policy "no-referrer" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header X-Permitted-Cross-Domain-Policies "none" always;
      add_header X-Robots-Tag "noindex, nofollow" always;
    '';
  };

  # Database setup
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
      {
        name = "nextcloud";
        ensureDBOwnership = true;
      }
    ];
  };

  # Redis configuration
  services.redis.servers.nextcloud = {
    enable = true;
    port = 6379;
  };

  # Create admin password file
  system.activationScripts.nextcloud-setup = ''
    if [ ! -f /var/lib/nextcloud/admin-pass ]; then
      mkdir -p /var/lib/nextcloud
      # don't worry, this has already been changed :)
      echo "ChangeThisPassword123!" > /var/lib/nextcloud/admin-pass
      chown nextcloud:nextcloud /var/lib/nextcloud/admin-pass
      chmod 600 /var/lib/nextcloud/admin-pass
    fi
  '';
}
