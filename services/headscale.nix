{ pkgs, ... }:

{
  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = 8080;
    settings = {
      server_url = "https://headscale.maixnor.com";
      dns = {
        magic_dns = true;
        base_domain = "probat.io";
        nameservers.global = [ "1.1.1.1" "1.0.0.1" ];
      };
      log.level = "info";
      policy = {
        mode = "file";
        path = "/etc/headscale/acl.yaml";
      };
    };
  };

  environment.etc."headscale/acl.yaml".text = ''
    acls:
      - action: accept
        src: ["tag:bierland"]
        dst: ["tag:bierland:*"]
      - action: accept
        src: ["tag:probatio-internal"]
        dst: ["tag:probatio-internal:*"]
      - action: accept
        src: ["tag:elastic-hub"]
        dst: ["tag:elastic-spoke:*"]
      - action: accept
        src: ["tag:elastic-spoke"]
        dst: ["tag:elastic-hub:*"]
      - action: accept
        src: ["tag:deploy"]
        dst: ["*:*"]

    tagOwners:
      tag:bierland: ["autogroup:nonroot"]
      tag:probatio-internal: ["autogroup:nonroot"]
      tag:elastic-hub: ["autogroup:nonroot"]
      tag:elastic-spoke: ["autogroup:nonroot"]
      tag:soc-external: ["autogroup:nonroot"]
      tag:deploy: ["autogroup:nonroot"]
  '';

  environment.etc."traefik/headscale.yml".text = ''
    http:
      routers:
        headscale:
          rule: "Host(`headscale.maixnor.com`)"
          service: "headscale"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      services:
        headscale:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8080"
  '';

  environment.systemPackages = [ pkgs.headscale ];
}
