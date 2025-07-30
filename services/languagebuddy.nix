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

  services.nginx.virtualHosts."prod.languagebuddy.maixnor.com" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8080/";
    };
  };

  services.nginx.virtualHosts."test.languagebuddy.maixnor.com" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8081/";
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
        port = 6379;
        requirePassFile = /etc/languagebuddy-dev.scrt;
        appendOnly = true;
        openFirewall = true;
        bind = null; # essentially 0.0.0.0
      };
      languagebuddy-prod = {
        enable = true;
        port = 6380;
        requirePassFile = /etc/languagebuddy-prod.scrt;
        appendOnly = true;
        openFirewall = true;
        bind = null; # only available from the host itself
      };
    };
  };
  

}
