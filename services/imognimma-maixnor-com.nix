{ config, pkgs, lib, ... }:

{
  # User and group for imognimma
  users.groups.imognimma = {};
  users.users.imognimma = {
    isSystemUser = true;
    group = "imognimma";
  };

  # User and group for abo-exit
  users.groups.abo-exit = {};
  users.users.abo-exit = {
    isSystemUser = true;
    group = "abo-exit";
  };

  # Add maixnor to the groups for editing purposes
  users.users.maixnor.extraGroups = [ "imognimma" "abo-exit" ];

  # Nginx configuration to serve the static files
  services.nginx = {
    enable = true;
    virtualHosts."imognimma.maixnor.com" = {
      listen = [ { addr = "127.0.0.1"; port = 8100; } ];
      root = "/var/www/imognimma.maixnor.com";
      extraConfig = ''
        autoindex off;
        port_in_redirect off;
        absolute_redirect off;
      '';
    };
    virtualHosts."abo-exit.maixnor.com" = {
      listen = [ { addr = "127.0.0.1"; port = 8101; } ];
      root = "/var/www/abo-exit.maixnor.com";
      extraConfig = ''
        autoindex off;
        port_in_redirect off;
        absolute_redirect off;
      '';
    };
  };

  # Traefik configuration
  environment.etc."traefik/imognimma-maixnor-com.yml" = lib.mkIf config.services.traefik.enable {
    text = ''
      http:
        routers:
          imognimma-maixnor-com:
            rule: "Host(`imognimma.maixnor.com`)"
            service: "imognimma-maixnor-com"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"

        services:
          imognimma-maixnor-com:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:8100"
    '';
  };

  environment.etc."traefik/abo-exit-maixnor-com.yml" = lib.mkIf config.services.traefik.enable {
    text = ''
      http:
        routers:
          abo-exit-maixnor-com:
            rule: "Host(`abo-exit.maixnor.com`)"
            service: "abo-exit-maixnor-com"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"

        services:
          abo-exit-maixnor-com:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:8101"
    '';
  };

  # Ensure the directories exist with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/www/imognimma.maixnor.com 0775 imognimma imognimma -"
    "d /var/www/abo-exit.maixnor.com 0775 abo-exit abo-exit -"
  ];
}
