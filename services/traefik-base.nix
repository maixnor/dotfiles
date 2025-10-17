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

  # ensuring /var/lib/traefik/acme.json exists with 600 permissions (othewise no certficate challenge)
  systemd.services.traefik-acme-setup = {
    description = "Set up Traefik ACME file permissions";
    wantedBy = [ "traefik.service" ];
    before = [ "traefik.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/traefik
      touch /var/lib/traefik/acme.json
      chown traefik:traefik /var/lib/traefik/acme.json
      chmod 600 /var/lib/traefik/acme.json
    '';
  };

  # ACME is now handled by Traefik, but keep this for compatibility
  security.acme = {
    acceptTerms = true;
    defaults.email = "benjamin@meixner.org";
  };
}
