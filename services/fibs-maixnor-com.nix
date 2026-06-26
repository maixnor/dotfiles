{ config, pkgs, lib, ... }:

{
  # User and group for the website
  users.groups.fibs = {};
  users.users.fibs = {
    isSystemUser = true;
    group = "fibs";
  };

  # Add maixnor to the group for editing purposes
  users.users.maixnor.extraGroups = [ "fibs" ];

  # Nginx configuration to serve the static files
  services.nginx = {
    enable = true;
    virtualHosts."fibs.maixnor.com" = {
      listen = [ { addr = "127.0.0.1"; port = 8095; } ];
      root = "/var/www/fibs.maixnor.com";
      extraConfig = ''
        autoindex off;
        port_in_redirect off;
        absolute_redirect off;
      '';
    };
  };

  # Traefik configuration
  environment.etc."traefik/fibs-maixnor-com.yml" = lib.mkIf config.services.traefik.enable {
    text = ''
      http:
        routers:
          fibs-maixnor-com:
            rule: "Host(`fibs.maixnor.com`)"
            service: "fibs-maixnor-com"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"

        services:
          fibs-maixnor-com:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:8095"
    '';
  };

  # Ensure the directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/www/fibs.maixnor.com 0775 fibs fibs -"
  ];
}
