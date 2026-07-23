{ config, pkgs, lib, ... }:

let
  port = 8099;
  rootDir = "/var/www/cloud.maixnor.com";
  
  pythonServer = pkgs.writeScriptBin "tracking-server" ''
    #!${pkgs.python3}/bin/python
    import http.server
    import socketserver
    import os

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory="${rootDir}", **kwargs)

        def log_message(self, format, *args):
            user_agent = self.headers.get('User-Agent', 'Unknown')
            # Extract real IP from X-Forwarded-For if available, otherwise use client_address
            forwarded = self.headers.get('X-Forwarded-For')
            real_ip = forwarded.split(',')[0].strip() if forwarded else self.client_address[0]
            
            log_line = f"[{self.log_date_time_string()}] IP: {real_ip}, User-Agent: {user_agent}, Request: {format%args}\n"
            
            log_file = os.path.join("${rootDir}", "log.txt")
            try:
                with open(log_file, "a") as f:
                    f.write(log_line)
            except Exception as e:
                print(f"Failed to write log: {e}")
            
            super().log_message(format, *args)

    # Use ThreadingTCPServer or just TCPServer, but allow address reuse
    class ReusableTCPServer(socketserver.TCPServer):
        allow_reuse_address = True

    with ReusableTCPServer(("", ${toString port}), Handler) as httpd:
        print("serving at port", ${toString port})
        httpd.serve_forever()
  '';
in
{
  # User and group for the website
  users.groups.tracking = {};
  users.users.tracking = {
    isSystemUser = true;
    group = "tracking";
  };

  # Add maixnor to the group for editing purposes
  users.users.maixnor.extraGroups = [ "tracking" ];

  # Systemd service for the python server
  systemd.services.tracking = {
    description = "Python web server for cloud.maixnor.com";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    
    preStart = ''
      cat > ${rootDir}/index.html << 'EOF'
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Tracking Service</title>
          <style>
              body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 600px; margin: 40px auto; padding: 20px; color: #333; }
              h1 { color: #2c3e50; }
              code { background: #f4f4f4; padding: 2px 5px; border-radius: 3px; font-family: monospace; }
          </style>
      </head>
      <body>
          <h1>Maixnor Tracking Service</h1>
          <p>Welcome to the custom tracking service for <code>cloud.maixnor.com</code>.</p>
          
          <h2>How It Works</h2>
          <p>This service operates a simple Python web server that intercepts incoming HTTP requests. Upon receiving a request, it logs:</p>
          <ul>
              <li>The real IP address of the requester (via Traefik's <code>X-Forwarded-For</code> header).</li>
              <li>The User-Agent string from the browser or client.</li>
          </ul>
          <p>This data is appended in real-time to a publicly accessible <a href="/log.txt">log.txt</a> file located in the root directory.</p>
          
          <h2>Tracking Pixel</h2>
          <p>You can embed a 1x1 transparent GIF tracking pixel into your emails or websites using the following snippet:</p>
          <pre><code>&lt;img src="https://cloud.maixnor.com/logo.gif" width="1" height="1" alt=""&gt;</code></pre>
          <p>When the pixel is loaded, the client's information will be recorded in the log.</p>
          <p>Here is the pixel in action (invisible): <img src="/logo.gif" width="1" height="1" alt="pixel"></p>
      </body>
      </html>
      EOF
      
      # Generate transparent 1x1 GIF
      echo "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" | ${pkgs.coreutils}/bin/base64 -d > ${rootDir}/logo.gif
      
      chown tracking:tracking ${rootDir}/index.html ${rootDir}/logo.gif
    '';

    serviceConfig = {
      ExecStart = "${pythonServer}/bin/tracking-server";
      User = "tracking";
      Group = "tracking";
      Restart = "always";
      WorkingDirectory = rootDir;
    };
  };

  # Traefik configuration
  environment.etc."traefik/tracking.yml" = lib.mkIf config.services.traefik.enable {
    text = ''
      http:
        routers:
          tracking:
            rule: "Host(`cloud.maixnor.com`)"
            service: "tracking"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"
        services:
          tracking:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:${toString port}"
    '';
  };

  # Ensure the directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d ${rootDir} 0775 tracking tracking -"
    "f ${rootDir}/log.txt 0664 tracking tracking - "
  ];
}
