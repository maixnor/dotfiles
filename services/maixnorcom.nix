
{ pkgs, ... }:

{
  # Create Traefik configuration file for maixnor.com sites
  environment.etc."traefik/maixnorcom.yml".text = ''
    http:
      routers:
        maixnor-com:
          rule: "Host(`maixnor.com`) || Host(`wieselburg.maixnor.com`)"
          service: "maixnor-com"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
        static-maixnor-com:
          rule: "Host(`static.maixnor.com`)"
          service: "static-maixnor-com"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      services:
        maixnor-com:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8090"
        static-maixnor-com:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8091"
  '';

  # Simple HTTP servers for static content
  systemd.services.maixnor-com-server = {
    description = "Static file server for maixnor.com";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server 8090 --directory /var/www/maixnor.com";
      Restart = "always";
      User = "nobody";
      Group = "nogroup";
    };
  };

  systemd.services.static-maixnor-com-server = {
    description = "Static file server for static.maixnor.com";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server 8091 --directory /var/www/static";
      Restart = "always";
      User = "nobody";
      Group = "nogroup";
    };
  };

  # Create necessary directories
  system.activationScripts.maixnorcom-setup = ''
    mkdir -p /var/www/{maixnor.com,static}
    chown -R nobody:nogroup /var/www
  '';
}
