{ pkgs, ... }:

let 
  runscript = pkgs.writeShellScriptBin "start" ''npm i && npm run build && ENV=PRODUCTION npm run start'';
  redis_socket = "/run/redis-languagebuddy-dev/socket.sock";
in
{

  systemd.services.languagebuddy-update = {
    description = "Pull latest code and restart app";
    path = with pkgs; [ git ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/maixnor/repo/languagebuddy";
      ExecStart = pkgs.writeShellScript "languagebuddy-update.sh" ''
        if git fetch origin main && ! git diff --quiet HEAD..origin/main; then
          git pull origin main
          systemctl --user restart languagebuddy-api.service
        fi
      '';
      User = "maixnor";
    };
  };

  systemd.timers.languagebuddy-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "minutely";
      Unit = "languagebuddy-update.service";
    };
  };

  services.nginx.virtualHosts."languagebuddy-test.maixnor.com" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8080/";
    };
  };

  systemd.services.languagebuddy-api = {
    description = "LanguageBuddy API";
    after = [ "network.target" "redis.service" ];
    wantedBy = [ "default.target" ];
    path = with pkgs; [ nodejs_24 bash ];
    script = "${runscript}/bin/start";
    serviceConfig = {
      WorkingDirectory = "/home/maixnor/repo/languagebuddy/backend";
      EnvironmentFile = "/home/maixnor/repo/languagebuddy/backend/.env";
      Restart = "always";
      User = "maixnor";
      PrivateNetwork = false;
      IPAddressAllow = [ "127.0.0.1" "::1" ];
    };
  };

  services.redis = {
    servers = {
      languagebuddy-dev = {
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
