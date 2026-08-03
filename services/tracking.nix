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
      cp ${./tracking-dashboard.html} ${rootDir}/index.html
      chmod 664 ${rootDir}/index.html
      
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
