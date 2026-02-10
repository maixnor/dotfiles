{ config, pkgs, lib, ... }:

{
  # User and group for the website
  users.groups.priority-oil = {};
  users.users.priority-oil = {
    isSystemUser = true;
    group = "priority-oil";
  };

  # Add maixnor to the group for editing purposes
  users.users.maixnor.extraGroups = [ "priority-oil" ];

  # Nginx configuration to serve the static files
  services.nginx = {
    enable = true;
    virtualHosts."priority-oil.com" = {
      listen = [ { addr = "127.0.0.1"; port = 8097; } ];
      root = "/var/www/priority-oil.com";
      extraConfig = ''
        autoindex off;
      '';
    };
  };

  # Traefik configuration
  environment.etc."traefik/priority-oil-com.yml" = lib.mkIf config.services.traefik.enable {
    text = ''
      http:
        routers:
          priority-oil-com:
            rule: "Host(`priority-oil.com`) || Host(`www.priority-oil.com`)"
            service: "priority-oil-com"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"

        services:
          priority-oil-com:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:8097"
    '';
  };

  # Ensure the directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/www/priority-oil.com 0775 priority-oil priority-oil -"
  ];
}
