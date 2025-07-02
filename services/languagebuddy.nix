{ pkgs, ... }:

{

  environment.systemPackages = with pkgs; [ nodejs_24 ];

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
    path = with pkgs; [ nodejs_24 ];
    serviceConfig = {
      WorkingDirectory = "/home/maixnor/repo/languagebuddy/backend";
      ExecStart = pkgs.writeShellScript "run.sh" ''pwd && npm -v && npm i && npm run build && ENV=PRODUCTION npm run start'';
      Restart = "always";
      User = "maixnor";
      EnvironmentFile = "/home/maixnor/repo/languagebuddy/backend/.env";
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
        # bind = null; # only available from the host itself
      };
    };
  };
  

}
