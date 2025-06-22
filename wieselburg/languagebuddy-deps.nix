{ config, pkgs, ... }:

{
  services.redis.servers.languagebuddy-test = {
    enable = true;
    port = 6380;
    appendOnly = true;
    openFirewall = true;
  };

  services.redis.servers.languagebuddy-prod = {
    enable = true;
    port = 6397;
    appendOnly = true;
    openFirewall = true;
  };

  systemd.services.languagebuddy-update = {
    description = "Pull latest code and restart app";
    path = with pkgs; [ git ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/maixnor/repo/languagebuddy";
      ExecStart = pkgs.writeShellScript "languagebuddy-update.sh" ''
        if git fetch origin main && ! git diff --quiet HEAD..origin/main; then
          git pull origin main
          systemctl --user restart languagebuddy-app.service || true
        fi
      '';
      User = "maixnor";
    };
  };

  systemd.timers.languagebuddy-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:*:0/60";
      Unit = "languagebuddy-update.service";
    };
  };

  systemd.services.languagebuddy-api = {
    description = "LanguageBuddy API";
    after = [ "network.target" "redis.service" ];
    wantedBy = [ "default.target" ];
    # idk why this does not want to link the binary properly
    path = with pkgs; [ nodejs_24 ];
    serviceConfig = {
      WorkingDirectory = "/home/maixnor/repo/languagebuddy/backend";
      ExecStart = pkgs.writeShellScript "run.sh" ''
        echo $REDIS_PORT
        node -v
        npm -v
        npm i
        ENV=PRODUCTION npm run start
      '';
      Restart = "always";
      User = "maixnor";
      EnvironmentFile = "/home/maixnor/repo/languagebuddy/backend/.env";
    };
  };
}
