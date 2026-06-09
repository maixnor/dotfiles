{ config, pkgs, lib, ... }:

let
  mountPoint = "${config.home.homeDirectory}/cloud/probatio/gdrive";
  sharedDrivesBase = "${config.home.homeDirectory}/cloud/probatio/shared";
  
  # List of shared drives found
  sharedDrives = [
    { name = "Knowledge_Base"; id = "0AHK9So00yj9YUk9PVA"; }
    { name = "Official";       id = "0ACp7XJF4uqjTUk9PVA"; }
    { name = "Projects";       id = "0ALr3MEQ5FpwPUk9PVA"; }
  ];

  # Helper to create a systemd service for a mount
  mkMountService = { name, remote, path, id ? null, extraArgs ? "" }: {
    Unit = {
      Description = "rclone mount for ${name}";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Install = { WantedBy = [ "default.target" ]; };
    Service = {
      Type = "simple";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p ${path}"
        "-/run/wrappers/bin/fusermount3 -u ${path}"
      ];
      ExecStart = let
        remotePath = if id == null then "${remote}:" else "${remote},team_drive=${id},root_folder_id=:";
      in ''
        ${pkgs.rclone}/bin/rclone mount "${remotePath}" "${path}" \
          --config /run/agenix/rclone-gdrive \
          --vfs-cache-mode full \
          --vfs-cache-max-age 24h \
          --vfs-cache-max-size 10G \
          --dir-cache-time 1000h \
          --drive-chunk-size 64M \
          --vfs-read-chunk-size 32M \
          --vfs-read-chunk-size-limit off \
          --buffer-size 128M \
          --no-modtime \
          --vfs-fast-fingerprint \
          --stats 1m ${extraArgs}
      '';
      ExecStop = "/run/wrappers/bin/fusermount3 -u ${path}";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = [ "PATH=/run/wrappers/bin:${pkgs.fuse3}/bin:$PATH" ];
    };
  };

in {
  home.packages = with pkgs; [ 
    fuse3 
    rclone 
    (pkgs.writeShellScriptBin "list-shared-drives-nix" ''
      # Fetch shared drives and format them as Nix attributes
      ${pkgs.rclone}/bin/rclone backend drives gdrive-probatio: --config /run/agenix/rclone-gdrive | \
      ${pkgs.jq}/bin/jq -r '.[] | "{ name = \"\(.name | gsub(" "; "_") | gsub("[^a-zA-Z0-9_]"; ""))\"; id = \"\(.id)\"; } # \(.name)"'
    '')
  ];

  systemd.user.services = (lib.listToAttrs (map (drive: {
    name = "rclone-mount-${drive.name}";
    value = mkMountService {
      inherit (drive) name id;
      remote = "gdrive-probatio";
      path = "${sharedDrivesBase}/${drive.name}";
    };
  }) sharedDrives)) // {
    rclone-gdrive-mount = mkMountService {
      name = "Main Google Drive";
      remote = "gdrive-probatio";
      path = mountPoint;
    };
  };
}
