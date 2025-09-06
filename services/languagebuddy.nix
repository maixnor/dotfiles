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

  # Create the A/B testing configuration file
  environment.etc."traefik/ab-testing.yml".text = ''
    http:
      routers:
        # Single production router with configurable weights
        languagebuddy-prod:
          rule: "Host(`languagebuddy.maixnor.com`)"
          service: "languagebuddy-weighted"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      services:
        languagebuddy-weighted:
          weighted:
            services:
              - name: "prod-languagebuddy"
                weight: 100
              - name: "test-languagebuddy"
                weight: 0
        prod-languagebuddy:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8080"
        test-languagebuddy:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8081"
  '';

  services.traefik = {
    enable = true;
    staticConfigOptions = {
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entrypoint = {
            to = "websecure";
            scheme = "https";
            permanent = true;
          };
        };
        websecure = {
          address = ":443";
          http.tls.certResolver = "letsencrypt";
        };
      };
      certificatesResolvers.letsencrypt = {
        acme = {
          email = "benjamin@meixner.org";
          storage = "/var/lib/traefik/acme.json";
          httpChallenge.entryPoint = "web";
        };
      };
      api = {
        dashboard = true;
        insecure = false;
      };
      providers = {
        file = {
          filename = "/etc/traefik/ab-testing.yml";
          watch = true;
        };
      };
    };
    dynamicConfigOptions = {
      http = {
        routers = {
          # Static routers (not affected by A/B testing)
          prod-languagebuddy = {
            rule = "Host(`prod.languagebuddy.maixnor.com`)";
            service = "prod-languagebuddy-static";
            entryPoints = ["websecure"];
            tls.certResolver = "letsencrypt";
          };
          test-languagebuddy = {
            rule = "Host(`test.languagebuddy.maixnor.com`)";
            service = "test-languagebuddy-static";
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
          # Static services for direct access
          prod-languagebuddy-static = {
            loadBalancer.servers = [{
              url = "http://127.0.0.1:8080";
            }];
          };
          test-languagebuddy-static = {
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
