{ pkgs, ... }:

let
  fallbackHtml = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Adhoc Tunnel Endpoint</title>
        <style>
            body { 
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; 
                max-width: 800px; 
                margin: 4rem auto; 
                padding: 0 1rem; 
                line-height: 1.6; 
                color: #333;
            }
            h1 { border-bottom: 2px solid #eee; padding-bottom: 0.5rem; }
            .container {
                background: #fff;
                padding: 2rem;
                border-radius: 8px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }
            pre { 
                background: #2d2d2d; 
                color: #f8f8f2; 
                padding: 1rem; 
                border-radius: 6px; 
                overflow-x: auto; 
                font-size: 0.9rem;
            }
            code { font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; }
            .status {
                display: inline-block;
                padding: 0.25rem 0.75rem;
                border-radius: 999px;
                background: #eee;
                font-size: 0.85rem;
                font-weight: bold;
                color: #666;
                margin-bottom: 1rem;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="status">Status: Idle</div>
            <h1>Adhoc Tunnel Endpoint</h1>
            <p>Nothing is currently running on the tunnel port (6969).</p>
            <p>To expose your local service (e.g., running on port <strong>8080</strong>) at this URL, run the following command on your machine:</p>
            <pre><code>ssh -R 6969:localhost:PORT wieselburg.maixnor.com</code></pre>
            <p><em>Note: Ensure your SSH key is authorized on wieselburg.</em></p>
            <p>Once the command is running, refresh this page to see your service.</p>
        </div>
    </body>
    </html>
  '';
in
{
  # 1. Fallback Service (Simple HTTP Server)
  # Serves the static HTML page on port 6970 when the tunnel is down.
  systemd.services.adhoc-fallback = {
    description = "Adhoc Tunnel Fallback Page";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # python3 is standard; bind to localhost to avoid external exposure if firewall fails
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server 6970 --bind 127.0.0.1 --directory ${fallbackHtml}";
      User = "nobody";
      Restart = "always";
    };
  };

  # 2. Traefik Configuration
  # Defines the router and middleware to handle the tunnel and fallback.
  environment.etc."traefik/adhoc.yml".text = ''
    http:
      routers:
        adhoc:
          rule: "Host(`adhoc.maixnor.com`)"
          service: "adhoc-service"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
          middlewares:
            - "adhoc-errors"

      middlewares:
        adhoc-errors:
          errors:
            # Catch 5xx errors (connection refused when tunnel is down)
            status: ["502", "504", "503", "500"]
            service: "adhoc-fallback"
            query: "/"

      services:
        adhoc-service:
          loadBalancer:
            servers:
              # The port the SSH tunnel binds to
              - url: "http://127.0.0.1:6969"
        
        adhoc-fallback:
          loadBalancer:
            servers:
              # The static fallback server
              - url: "http://127.0.0.1:6970"
  '';
}
