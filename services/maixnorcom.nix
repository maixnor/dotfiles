
{ pkgs, config, lib, ... }:

let
  cfg = config.services.traefik;
in
{
  # Create Traefik configuration file for maixnor.com sites if traefik is enabled
  environment.etc."traefik/maixnorcom.yml" = lib.mkIf cfg.enable {
    text = ''
    http:
      routers:
        maixnor-com:
          rule: "Host(`maixnor.com`) || Host(`wieselburg.maixnor.com`) || Host(`wb.maixnor.com`)"
          service: "maixnor-com"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
        maixnor-com-ws:
          rule: "Host(`wb.maixnor.com`, `maixnor.com`, `wieselburg.maixnor.com`) && PathPrefix(`/ws-logs`)"
          priority: 1000
          service: "maixnor-com-ws"
          middlewares:
            - "ws-strip-prefix"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
        static-maixnor-com:
          rule: "Host(`static.maixnor.com`)"
          service: "static-maixnor-com"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      middlewares:
        ws-strip-prefix:
          stripPrefix:
            prefixes:
              - "/ws-logs"

      services:
        maixnor-com:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8090"
        maixnor-com-ws:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8092"
        static-maixnor-com:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8091"
  '';
  };

  # Simple HTTP servers for static content
  systemd.services.maixnor-com-server = {
    description = "Static file server for maixnor.com";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server 8090 --directory /var/www/maixnor.com";
      Restart = "always";
      User = "maixnor";
      Group = "users";
    };
  };

  systemd.services.maixnor-logs-ws = {
    description = "WebSocket log streamer for maixnor.com";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    path = with pkgs; [ websocketd coreutils ];
    serviceConfig = {
      ExecStart = "${pkgs.websocketd}/bin/websocketd --port=8092 --address=127.0.0.1 ${pkgs.coreutils}/bin/tail -f -n 100 /var/www/maixnor.com/update.log";
      Restart = "always";
      User = "maixnor";
      Group = "users";
    };
  };

  systemd.services.maixnor-status-gen = {
    description = "Generate status.json for maixnor.com dashboard";
    after = [ "network.target" ];
    path = with pkgs; [ systemd git jq coreutils gnugrep bash ];
    script = ''
      set -euo pipefail
      
      # Ensure directory and log file exist
      mkdir -p /var/www/maixnor.com
      touch /var/www/maixnor.com/update.log
      chmod 644 /var/www/maixnor.com/update.log
      
      IS_UPDATING=$(systemctl is-active autoupdate.service || echo "inactive")
      
      # Use the current repo path
      REPO_PATH="/home/maixnor/repo/dotfiles"
      if [ -d "$REPO_PATH/.git" ]; then
        COMMIT_HASH=$(git -C "$REPO_PATH" rev-parse HEAD || echo "unknown")
        COMMIT_MSG=$(git -C "$REPO_PATH" log -1 --pretty=%B || echo "unknown")
      else
        COMMIT_HASH="not-a-repo"
        COMMIT_MSG="not-a-repo"
      fi

      # Use a temporary file to avoid partial reads
      TMP_FILE=$(mktemp)
      
      jq -n \
        --arg updating "$IS_UPDATING" \
        --arg hash "$COMMIT_HASH" \
        --arg msg "$COMMIT_MSG" \
        --arg host "$(hostname)" \
        --arg time "$(date -Iseconds)" \
        '{
          is_updating: ($updating == "active"),
          commit_hash: $hash,
          commit_msg: $msg,
          hostname: $host,
          timestamp: $time
        }' > "$TMP_FILE"
      
      mv "$TMP_FILE" /var/www/maixnor.com/status.json
      chmod 644 /var/www/maixnor.com/status.json
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root"; # Needs root to read journal for autoupdate.service if not in systemd-journal group
    };
  };

  systemd.timers.maixnor-status-gen = {
    description = "Timer for maixnor-status-gen";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
  };

  systemd.services.static-maixnor-com-server = {
    description = "Static file server for static.maixnor.com";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server 8091 --directory /var/www/static";
      Restart = "always";
      User = "nobody";
      Group = "nogroup";
    };
  };

  # Manage directories and files directly via Nix
  systemd.tmpfiles.rules = [
    "d /var/www/maixnor.com 0755 maixnor users -"
    "d /var/www/static 0755 nobody nogroup -"
    "L+ /var/www/maixnor.com/index.html - nobody nogroup - ${./dashboard.html}"
  ];
}
