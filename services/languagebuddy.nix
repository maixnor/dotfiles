{ pkgs, ... }:

let 
  redis_socket = "/run/redis-languagebuddy-dev/socket.sock";
in
{

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
    path = with pkgs; [ nodejs_24 ];
    script = "node main.js";
    serviceConfig = {
      WorkingDirectory = "/var/www/languagebuddy/test";
      EnvironmentFile = "/var/www/languagebuddy/test/.env";
      Restart = "always";
      User = "maixnor";
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
    after = [ "network.target" "redis.service" ];
    wantedBy = [ "default.target" ];
    path = with pkgs; [ nodejs_24 ];
    script = "node main.js";
    serviceConfig = {
      WorkingDirectory = "/var/www/languagebuddy/prod";
      EnvironmentFile = "/var/www/languagebuddy/prod/.env";
      Restart = "always";
      User = "maixnor";
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
