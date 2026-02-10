{ pkgs, lib, config, ... }:

let
  cfg = config.services.traefik;
  errorPort = 8093;
  errorPageDir = "/var/www/error-pages";
in
{
  # Simple server for error pages
  systemd.services.error-page-server = {
    description = "Static file server for custom error pages";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server ${toString errorPort} --directory ${errorPageDir}";
      Restart = "always";
      User = "web-static";
      Group = "web-static";
    };
  };

  # Create the 404 page
  systemd.tmpfiles.rules = [
    "d ${errorPageDir} 0755 web-static web-static -"
    "L+ ${errorPageDir}/index.html - - - ${pkgs.writeText "404.html" ''
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>404 - Not Found | Maya</title>
          <style>
              body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #121212; color: white; text-align: center; }
              .container { padding: 2rem; }
              h1 { font-size: 6rem; margin: 0; color: #ff4b2b; }
              h2 { font-size: 2rem; margin-bottom: 1rem; }
              p { color: #888; margin-bottom: 2rem; }
              .back-link { text-decoration: none; color: #00a4dc; font-weight: bold; border: 1px solid #00a4dc; padding: 10px 20px; border-radius: 4px; transition: all 0.3s; }
              .back-link:hover { background: #00a4dc; color: white; }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>404</h1>
              <h2>Lost in Space?</h2>
              <p>The page you are looking for doesn't exist or has been moved.</p>
              <a href="https://maixnor.com" class="back-link">Take me home</a>
          </div>
      </body>
      </html>
    ''}"
  ];

  # Traefik catch-all router
  environment.etc."traefik/errors.yml" = lib.mkIf cfg.enable {
    text = ''
      http:
        routers:
          catch-all:
            rule: "HostRegexp(`{subdomain:[a-z0-9-]+}.maixnor.com`)"
            priority: 1
            service: "error-page-service"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"

        services:
          error-page-service:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:${toString errorPort}"
    '';
  };
}
