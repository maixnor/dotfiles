{ config, pkgs, lib, ... }:

{
  # Collabora Online for LibreOffice Online (OpenOffice alternative)
  virtualisation.oci-containers.containers.collabora-online = {
    image = "collabora/code:latest";
    ports = [ "9980:9980" ];
    environment = {
      # Domain where Collabora will be accessible
      domain = "office\\.maixnor\\.com";
      # Extra parameters for LibreOffice
      extra_params = "--o:ssl.enable=false --o:ssl.termination=true --o:welcome.enable=false --o:user_interface.mode=notebookbar";
      # Disable SSL since we handle it with nginx
      DONT_GEN_SSL_CERT = "true";
      # Security settings
      username = "admin";
      password = "ChangeThisPassword123!";
    };
    extraOptions = [
      "--cap-add=MKNOD"
    ];
  };

  # Nginx configuration for Collabora Online
  services.nginx.virtualHosts."office.maixnor.com" = {
    forceSSL = true;
    enableACME = true;
    
    # Special configuration needed for Collabora
    extraConfig = ''
      # static files
      location ^~ /browser {
        proxy_pass http://127.0.0.1:9980;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }

      # WOPI discovery URL
      location ^~ /hosting/discovery {
        proxy_pass http://127.0.0.1:9980;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }

      # Capabilities
      location ^~ /hosting/capabilities {
        proxy_pass http://127.0.0.1:9980;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }

      # Main websocket
      location ~ ^/cool/(.*)/ws$ {
        proxy_pass http://127.0.0.1:9980;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 36000s;
      }

      # Download, presentation and image upload
      location ~ ^/(c|l)ool {
        proxy_pass http://127.0.0.1:9980;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }

      # Admin Console websocket
      location ^~ /cool/adminws {
        proxy_pass http://127.0.0.1:9980;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 36000s;
      }
    '';
    
    locations."/" = {
      proxyPass = "http://127.0.0.1:9980";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Allow large file uploads for documents
        client_max_body_size 100M;
      '';
    };
  };
}
