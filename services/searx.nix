{ pkgs, ... }:

{
  services.searx.enable = true;
  services.searx.redisCreateLocally = true;
  services.searx.settings = {
    server.port = 6666;
    server.bind_address = "0.0.0.0";
    server.secret_key = "definetelysecret";
    formats = [ "html" "json" "csv" ];
  };

  networking.firewall.allowedTCPPorts = [ 6666 ];

  # Create Traefik configuration file for Searx
  environment.etc."traefik/searx.yml".text = ''
    http:
      routers:
        searx:
          rule: "Host(`search.maixnor.com`)"
          service: "searx"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      services:
        searx:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:6666"
  '';
}
