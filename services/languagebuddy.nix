{ pkgs, ... }:

let 
  redis_socket = "/run/redis-languagebuddy-dev/socket.sock";
in
{
  # Create dedicated user and group for LanguageBuddy
  users.users.languagebuddy = {
    isSystemUser = true;
    group = "languagebuddy";
    description = "LanguageBuddy service user";
  };

  users.groups.languagebuddy = {
    members = [ "maixnor" "nginx" ];
  };

  services.nginx = {
    enable = true;
    defaultHTTPListenPort = 8181; # Avoid conflict with Traefik on port 80
    virtualHosts."languagebuddy.maixnor.com" = {
      root = "/var/www/languagebuddy/web";
      listen = [{ addr = "127.0.0.1"; port = 8082; }];
      locations."/" = {
        tryFiles = "$uri $uri/ /index.html";
        extraConfig = ''
          proxy_hide_header Content-Security-Policy;
          proxy_hide_header X-Frame-Options;
        '';
      };
    };
  };

  systemd.services.languagebuddy-setup = {
    description = "Set up LanguageBuddy directory permissions";
    wantedBy = [ "multi-user.target" ];
    before = [ "languagebuddy-api-prod.service" "languagebuddy-api-test.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      mkdir -p /var/www/languagebuddy/{test,prod,web}
      chown -R languagebuddy:languagebuddy /var/www/languagebuddy
      # Ensure group (including nginx) can read/execute all files/dirs
      chmod -R 770 /var/www/languagebuddy
    '';
  };

  # Create Traefik configuration file for LanguageBuddy
  environment.etc."traefik/languagebuddy.yml".text = ''
    http:
      routers:
        # Frontend router
        languagebuddy-frontend:
          rule: "Host(`languagebuddy.maixnor.com`)"
          service: "languagebuddy-frontend"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

        # API router
        api-languagebuddy-main:
          rule: "Host(`api.languagebuddy.maixnor.com`)"
          service: "prod-languagebuddy"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
        
        # Direct access routers (test remains)
        test-languagebuddy:
          rule: "Host(`test.languagebuddy.maixnor.com`)"
          service: "test-languagebuddy"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      services:
        # Frontend service
        languagebuddy-frontend:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8082"

        # Backend services (prod and test remain)
        prod-languagebuddy:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8080"
        
        test-languagebuddy:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8081"
  '';



  systemd.services.languagebuddy-api-test = {
    description = "LanguageBuddy API Test Environment";
    after = [ "network.target" "redis.service" "languagebuddy-setup.service" ];
    requires = [ "languagebuddy-setup.service" ];
    wantedBy = [ "default.target" ];
    path = with pkgs; [ nodejs_24 ];
    script = "node main.js";
    serviceConfig = {
      WorkingDirectory = "/var/www/languagebuddy/test";
      EnvironmentFile = "/var/www/languagebuddy/test/.env";
      Restart = "always";
      User = "languagebuddy";
      Group = "languagebuddy";
      PrivateNetwork = false;
      IPAddressAllow = [ "127.0.0.1" "::1" ];
      SyslogIdentifier = "languagebuddy-test";
    };
    environment = {
      PORT = "8081";
      NODE_ENV = "TEST";
      LOG_LEVEL = "info";
      ENVIRONMENT = "TEST";
      SERVICE_NAME = "languagebuddy";
      TEMPO_ENDPOINT = "http://127.0.0.1:4318";
    };
  };

  systemd.services.languagebuddy-api-prod = {
    description = "LanguageBuddy API Production";
    after = [ "network.target" "redis.service" "languagebuddy-setup.service" ];
    requires = [ "languagebuddy-setup.service" ];
    wantedBy = [ "default.target" ];
    path = with pkgs; [ nodejs_24 ];
    script = "node main.js";
    serviceConfig = {
      WorkingDirectory = "/var/www/languagebuddy/prod";
      EnvironmentFile = "/var/www/languagebuddy/prod/.env";
      Restart = "always";
      User = "languagebuddy";
      Group = "languagebuddy";
      PrivateNetwork = false;
      IPAddressAllow = [ "127.0.0.1" "::1" ];
      SyslogIdentifier = "languagebuddy-prod";
    };
    environment = {
      PORT = "8080";
      NODE_ENV = "PRODUCTION";
      LOG_LEVEL = "info";
      ENVIRONMENT = "PROD";
      SERVICE_NAME = "languagebuddy";
      TEMPO_ENDPOINT = "http://127.0.0.1:4318";
    };
  };

  services.redis = {
    servers = {
      languagebuddy-test = {
        enable = true;
        port = 6381;
        requirePassFile = /etc/languagebuddy-dev.scrt;
        appendOnly = true;
        openFirewall = true;
        bind = null;
      };
      languagebuddy-prod = {
        enable = true;
        port = 6380;
        requirePassFile = /etc/languagebuddy-prod.scrt;
        appendOnly = true;
        openFirewall = true;
        bind = null;
      };
    };
  };
  

}
