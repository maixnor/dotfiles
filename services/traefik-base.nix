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
        metrics = {
          address = ":8002";
        };
      };
      metrics = {
        prometheus = {
          entryPoint = "metrics";
          addEntryPointsLabels = true;
          addRoutersLabels = true;
          addServicesLabels = true;
        };
      };
      certificatesResolvers.letsencrypt = {
        acme = {
          email = "benjamin@meixner.org";
          storage = "/var/lib/traefik/acme.json";
          dnsChallenge = {
            provider = "namecheap";
            # Using a custom resolver can help with DNS propagation issues
            resolvers = [ "1.1.1.1:53" "8.8.8.8:53" ];
          };
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

  systemd.services.traefik.serviceConfig.EnvironmentFile = [ "/var/lib/traefik/secrets.env" ];

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
      touch /var/lib/traefik/secrets.env
      chown traefik:traefik /var/lib/traefik/acme.json /var/lib/traefik/secrets.env
      chmod 600 /var/lib/traefik/acme.json /var/lib/traefik/secrets.env
    '';
  };

  # ACME is now handled by Traefik, but keep this for compatibility
  security.acme = {
    acceptTerms = true;
    defaults.email = "benjamin@meixner.org";
  };
}
