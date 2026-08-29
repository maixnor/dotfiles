{ pkgs, ... }:

{
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
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
        path = "/etc/headscale/acl.json";
      };
    };
  };

  environment.etc."headscale/acl.json".text = ''
    {
      "acls": [
        { "action": "accept", "src": ["tag:bierland"], "dst": ["tag:bierland:*"] },
        { "action": "accept", "src": ["tag:probatio-internal"], "dst": ["tag:probatio-internal:*"] },
        { "action": "accept", "src": ["tag:elastic-hub"], "dst": ["tag:elastic-spoke:*"] },
        { "action": "accept", "src": ["tag:elastic-spoke"], "dst": ["tag:elastic-hub:*"] },
        { "action": "accept", "src": ["tag:deploy"], "dst": ["*:*"] }
      ],
      "groups": {
        "group:admin": ["internal@probat.io", "external@probat.io", "admin@probat.io"]
      },
      "tagOwners": {
        "tag:bierland": ["group:admin"],
        "tag:probatio-internal": ["group:admin"],
        "tag:elastic-hub": ["group:admin"],
        "tag:elastic-spoke": ["group:admin"],
        "tag:soc-external": ["group:admin"],
        "tag:deploy": ["group:admin"]
      }
    }
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

  networking.firewall.allowedTCPPorts = [ 8080 ];

  environment.systemPackages = [ pkgs.headscale ];
}
