{ config, pkgs, lib, ... }:

{
  # User and group for the website
  users.groups.hermes-meshara = {};
  users.users.hermes-meshara = {
    isSystemUser = true;
    group = "hermes-meshara";
  };

  # Add maixnor to the group for editing purposes
  users.users.maixnor.extraGroups = [ "hermes-meshara" ];

  # Nginx configuration to serve the static files
  services.nginx = {
    enable = true;
    virtualHosts."hermes.meshara.net" = {
      listen = [ { addr = "127.0.0.1"; port = 8098; } ];
      root = "/var/www/hermes.meshara.net";
      extraConfig = ''
        autoindex off;
        port_in_redirect off;
        absolute_redirect off;
      '';
    };
  };

  # Traefik configuration
  environment.etc."traefik/hermes-meshara-net.yml" = lib.mkIf config.services.traefik.enable {
    text = ''
      http:
        routers:
          hermes-meshara-net:
            rule: "Host(`hermes.meshara.net`) || Host(`www.hermes.meshara.net`)"
            service: "hermes-meshara-net"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"

        services:
          hermes-meshara-net:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:8098"
    '';
  };

  # Ensure the directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/www/hermes.meshara.net 0775 hermes-meshara hermes-meshara -"
  ];
}
