{ config, pkgs, lib, ... }:

let
  mountPoint = "${config.home.homeDirectory}/cloud/probatio/gdrive";
in {
  home.packages = [ pkgs.rclone pkgs.fuse3 ];

  age.secrets.rclone-gdrive = {
    file = ../secrets/rclone-gdrive.age;
  };

  systemd.user.services.rclone-gdrive-mount = {
    Unit = {
      Description = "rclone Google Drive Mount";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "notify";
      # Ensure the secret file exists before starting
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}"
        "${pkgs.bash}/bin/bash -c 'test -f ${config.age.secrets.rclone-gdrive.path} || (echo \"Secret file missing! Run agenix -e secrets/rclone-gdrive.age\" && exit 1)'"
      ];
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount gdrive: ${mountPoint} \
          --config ${config.home.homeDirectory}/.config/rclone/rclone.conf \
          --vfs-cache-mode full \
          --vfs-cache-max-age 24h \
          --vfs-cache-max-size 10G \
          --vfs-poll-interval 15s \
          --dir-cache-time 1000h \
          --drive-chunk-size 64M \
          --vfs-read-chunk-size 32M \
          --vfs-read-chunk-size-limit off \
          --buffer-size 128M \
          --no-modtime \
          --vfs-fast-fingerprint \
          --stats 1m
      '';
      ExecStop = "/run/wrappers/bin/fusermount3 -u ${mountPoint}";
      Restart = "on-failure";
      RestartSec = "10s";
      # Ensure system wrappers are in path for setuid fusermount3
      Environment = [ "PATH=/run/wrappers/bin:${pkgs.fuse3}/bin:$PATH" ];
      EnvironmentFile = [ config.age.secrets.rclone-gdrive.path ];
    };
  };
}
