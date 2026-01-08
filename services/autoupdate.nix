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
        default = "wb.maixnor.com";
      };
    };
  };

  config = mkIf cfg.enable { 
    systemd.timers.autoupdate-timer = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "autoupdate.service";
      };
    };

    systemd.services.autoupdate = {
      description = "Update system to latest state on GitHub";
      path = with pkgs; [ git just ];
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "/home/maixnor/repo/dotfiles";
        User = "maixnor";
        ExecStart = pkgs.writeShellScript "autoupdate.sh" ''
          if git fetch origin main && ! git diff --quiet HEAD..origin/main; then
            git pull origin main
            just ${config.networking.hostName}
          fi
        '';
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
              rule: "Host(`${cfg.webhook.domain}`) && Path(`/update`)"
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
