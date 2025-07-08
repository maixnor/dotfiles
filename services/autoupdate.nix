{ pkgs, lib, ... }:

with lib;
let 
  cfg = config.services.autoupdate;
in
{
  options.services.autoupdate = {
    enable = mkEnableOption "Update system to latest state on GitHub";

    hostname = mkOption {
      type = types.string;
      default = "changeme";
      description = "hostname after just command";
    };
  };

  config = mkIf cfg.enable { 
    systemd.services.autoupdate = {
      description = "Update system to latest state on GitHub";
      path = with pkgs; [ git just ];
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "/home/maixnor/repo/languagebuddy";
        ExecStart = pkgs.writeShellScript "autoupdate.sh" ''
          if git fetch origin main && ! git diff --quiet DEAD..origin/main; then
            git pull origin main
            just ${cfg.hostname}
        '';
      };
    };

  };

}
