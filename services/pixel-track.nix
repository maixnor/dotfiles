{ config, pkgs, ... }:

let
  domain = "pixel.maixnor.com";
  port = 3005;
in
{
  # Setup service to clone and build the image
  systemd.services.pixel-track-setup = {
    description = "Clone and build pixel-track image";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      export PATH=$PATH:${pkgs.git}/bin:${pkgs.podman}/bin
      mkdir -p /var/lib/pixel-track/src
      if [ ! -d /var/lib/pixel-track/src/.git ]; then
        git clone https://github.com/tinystrack/pixel-track.git /var/lib/pixel-track/src
      else
        cd /var/lib/pixel-track/src
        git pull
      fi
      
      # Patch the UI bug where it uses ID instead of Token
      sed -i 's/''${BASE}\/t\/''${id}/''${BASE}\/t\/''${p.token}/g' /var/lib/pixel-track/src/public/index.html
      
      cd /var/lib/pixel-track/src
      podman build -t pixel-track:local .
    '';
  };

  virtualisation.oci-containers.containers."pixel-track" = {
    image = "pixel-track:local";
    ports = [ "127.0.0.1:${toString port}:3000" ];
    volumes = [
      "/var/lib/pixel-track:/app/db"
    ];
    environment = {
      NODE_ENV = "production";
      DB_PATH = "/app/db/pixel-track.db";
    };
  };

  systemd.services.podman-pixel-track = {
    after = [ "pixel-track-setup.service" ];
    requires = [ "pixel-track-setup.service" ];
  };

  # Traefik configuration
  environment.etc."traefik/pixel-track.yml" = {
    text = ''
      http:
        routers:
          pixel-track:
            rule: "Host(`${domain}`)"
            entryPoints:
              - "websecure"
            service: "pixel-track"
            tls:
              certResolver: "letsencrypt"
        services:
          pixel-track:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:${toString port}"
    '';
  };

  # Open firewall for the port if needed (though Traefik handles external access)
  # networking.firewall.allowedTCPPorts = [ port ];

  # Ensure the data directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/pixel-track 0750 root root -"
  ];
}
