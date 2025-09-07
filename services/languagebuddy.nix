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
          systemctl --user restart languagebuddy-api-prod.service
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

  services.traefik.dynamicConfigOptions = {
    http = {
      routers = {
        # Main production router with A/B testing
        languagebuddy-main = {
          rule = "Host(`languagebuddy.maixnor.com`)";
          service = "languagebuddy-weighted";
          entryPoints = ["websecure"];
          tls.certResolver = "letsencrypt";
        };
        # Direct access routers
        prod-languagebuddy = {
          rule = "Host(`prod.languagebuddy.maixnor.com`)";
          service = "prod-languagebuddy";
          entryPoints = ["websecure"];
          tls.certResolver = "letsencrypt";
        };
        test-languagebuddy = {
          rule = "Host(`test.languagebuddy.maixnor.com`)";
          service = "test-languagebuddy";
          entryPoints = ["websecure"];
          tls.certResolver = "letsencrypt";
        };
        prod-redis = {
          rule = "Host(`prod.redis.maixnor.com`)";
          service = "prod-redis";
          entryPoints = ["websecure"];
          tls.certResolver = "letsencrypt";
        };
        test-redis = {
          rule = "Host(`test.redis.maixnor.com`)";
          service = "test-redis";
          entryPoints = ["websecure"];
          tls.certResolver = "letsencrypt";
        };
      };
      services = {
        # Weighted service for A/B testing
        languagebuddy-weighted = {
          weighted = {
            services = [
              {
                name = "prod-languagebuddy";
                weight = 100;
              }
              {
                name = "test-languagebuddy";
                weight = 0;
              }
            ];
          };
        };
        # Backend services
        prod-languagebuddy = {
          loadBalancer.servers = [{
            url = "http://127.0.0.1:8080";
          }];
        };
        test-languagebuddy = {
          loadBalancer.servers = [{
            url = "http://127.0.0.1:8081";
          }];
        };
        prod-redis = {
          loadBalancer.servers = [{
            url = "http://127.0.0.1:6380";
          }];
        };
        test-redis = {
          loadBalancer.servers = [{
            url = "http://127.0.0.1:6381";
          }];
        };
      };
    };
  };

  systemd.services.languagebuddy-api-test = {
    description = "LanguageBuddy API";
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
