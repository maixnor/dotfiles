{ pkgs, lib, config, ... }:

with lib;
let 
  cfg = config.services.autoupdate;
  traefikEnabled = config.services.traefik.enable;
in
{
  options.services.autoupdate = {
    enable = mkEnableOption "Update system to latest state on GitHub";

    webhook = {
      port = mkOption {
        type = types.int;
        default = 9001;
        description = "Port for the webhook listener";
      };
      domain = mkOption {
        type = types.str;
        default = "${config.networking.hostName}.maixnor.com";
        description = "Domain name for the webhook";
      };
    };
  };

  config = mkIf cfg.enable { 
    systemd.timers.autoupdate-timer = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        OnBootSec = "5min";
        Persistent = true;
        Unit = "autoupdate.service";
      };
    };

    systemd.services.autoupdate = {
      description = "Update system to latest state on GitHub";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = with pkgs; [ git just coreutils bash ];
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "/home/maixnor/repo/dotfiles";
        User = "maixnor";
        Nice = 19;
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.writeShellScript "autoupdate.sh" ''
          # Load the global profile to get a standard environment (PATH, etc.)
          if [ -f /etc/profile ]; then
            . /etc/profile
          fi

          # Wait if system just booted to avoid resource contention
          uptime_s=$(cat /proc/uptime | cut -d. -f1)
          if [ "$uptime_s" -lt 300 ]; then
            sleep $((300 - uptime_s))
          fi

          # Retry mechanism for git fetch
          MAX_RETRIES=5
          RETRY_COUNT=0
          while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            if git fetch origin main; then
              break
            fi
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "Fetch failed, retrying in 10 seconds... ($RETRY_COUNT/$MAX_RETRIES)"
            sleep 10
          done

          if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo "Failed to fetch from GitHub after $MAX_RETRIES attempts."
            exit 1
          fi

          if ! git diff --quiet HEAD..origin/main; then
            git pull origin main
            just ${config.networking.hostName}
          fi
        ''} 2>&1 | stdbuf -oL tee /var/www/maixnor.com/update.log'";
      };
    };

    systemd.services.webhook-update = mkIf traefikEnabled {
      description = "Webhook listener for system updates";
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ webhook systemd ];
      serviceConfig = {
        ExecStart = "${pkgs.webhook}/bin/webhook -hooks ${pkgs.writeText "hooks.json" (builtins.toJSON [
          {
            id = "update";
            execute-command = "${pkgs.systemd}/bin/systemctl";
            pass-arguments-to-command = [
              { source = "string"; name = "start"; }
              { source = "string"; name = "autoupdate.service"; }
            ];
            response-message = "Update triggered";
          }
        ])} -port ${toString cfg.webhook.port} -verbose";
        User = "root";
      };
    };

    environment.etc."traefik/autoupdate.yml" = mkIf traefikEnabled {
      text = ''
        http:
          routers:
            webhook-update:
              rule: "Host(`${cfg.webhook.domain}`) && Path(`/hooks/update`)"
              priority: 100
              service: "webhook-update"
              entryPoints:
                - "websecure"
              tls:
                certResolver: "letsencrypt"
          services:
            webhook-update:
              loadBalancer:
                servers:
                  - url: "http://127.0.0.1:${toString cfg.webhook.port}"
      '';
    };

  };

}
