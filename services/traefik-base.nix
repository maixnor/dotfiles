{ pkgs, ... }:

{
  # Traefik base configuration
  services.traefik = {
    enable = true;
    staticConfigOptions = {
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entrypoint = {
            to = "websecure";
            scheme = "https";
            permanent = true;
          };
        };
        websecure = {
          address = ":443";
          http.tls.certResolver = "letsencrypt";
        };
      };
      certificatesResolvers.letsencrypt = {
        acme = {
          email = "benjamin@meixner.org";
          storage = "/var/lib/traefik/acme.json";
          httpChallenge.entryPoint = "web";
        };
      };
      api = {
        dashboard = true;
        insecure = false;
      };
      providers = {
        file = {
          directory = "/etc/traefik";
          watch = true;
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # ACME is now handled by Traefik, but keep this for compatibility
  security.acme = {
    acceptTerms = true;
    defaults.email = "benjamin@meixner.org";
  };
}
