{ pkgs, ... }:

let 
  runscript-swc = pkgs.writeShellScriptBin "start" ''npm i && npm run build:swc && ENV=PRODUCTION npm run start'';
  runscript = pkgs.writeShellScriptBin "start" ''npm i && npm run build && ENV=PRODUCTION npm run start'';
  redis_socket = "/run/redis-languagebuddy-dev/socket.sock";
in
{

  systemd.services.languagebuddy-api-test-update = {
    description = "Pull latest code and restart app";
    path = with pkgs; [ git ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/maixnor/repo/languagebuddy";
      ExecStart = pkgs.writeShellScript "languagebuddy-update.sh" ''
        if git fetch origin main && ! git diff --quiet HEAD..origin/main; then
          git pull origin main
          systemctl --user restart languagebuddy-api-test.service
        fi
      '';
      User = "maixnor";
    };
  };

  systemd.timers.languagebuddy-api-test-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "minutely";
      Unit = "languagebuddy-update.service";
    };
  };

  # Create Traefik configuration file for LanguageBuddy
  environment.etc."traefik/languagebuddy.yml".text = ''
    http:
      routers:
        # Main production router with A/B testing
        languagebuddy-main:
          rule: "Host(`languagebuddy.maixnor.com`)"
          service: "languagebuddy-weighted"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
        
        # Direct access routers
        prod-languagebuddy:
          rule: "Host(`prod.languagebuddy.maixnor.com`)"
          service: "prod-languagebuddy"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
        
        test-languagebuddy:
          rule: "Host(`test.languagebuddy.maixnor.com`)"
          service: "test-languagebuddy"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      services:
        # Weighted service for A/B testing
        languagebuddy-weighted:
          weighted:
            services:
              - name: "prod-languagebuddy"
                weight: 100
              - name: "test-languagebuddy"
                weight: 0
        
        # Backend services
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
    after = [ "network.target" "redis.service" ];
    wantedBy = [ "default.target" ];
    path = with pkgs; [ nodejs_24 bash ];
    script = "${runscript-swc}/bin/start";
    serviceConfig = {
      WorkingDirectory = "/home/maixnor/repo/languagebuddy/backend";
      EnvironmentFile = "/home/maixnor/repo/languagebuddy/backend/.env";
      Restart = "always";
      User = "maixnor";
      PrivateNetwork = false;
      IPAddressAllow = [ "127.0.0.1" "::1" ];
      SyslogIdentifier = "languagebuddy-test";
    };
    environment = {
      PORT = "8081";
      NODE_ENV = "production";
      LOG_LEVEL = "info";
      ENVIRONMENT = "test";
      SERVICE_NAME = "languagebuddy";
    };
  };

  systemd.services.languagebuddy-api-prod = {
    description = "LanguageBuddy API Production";
    after = [ "network.target" "redis.service" ];
    wantedBy = [ "default.target" ];
    path = with pkgs; [ nodejs_24 bash ];
    script = "${runscript-swc}/bin/start";
    serviceConfig = {
      WorkingDirectory = "/home/maixnor/repo/languagebuddy-prod/backend";
      EnvironmentFile = "/home/maixnor/repo/languagebuddy-prod/backend/.env";
      Restart = "always";
      User = "maixnor";
      PrivateNetwork = false;
      IPAddressAllow = [ "127.0.0.1" "::1" ];
      SyslogIdentifier = "languagebuddy-prod";
    };
    environment = {
      PORT = "8080";
      NODE_ENV = "production";
      LOG_LEVEL = "info";
      ENVIRONMENT = "prod";
      SERVICE_NAME = "languagebuddy";
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
