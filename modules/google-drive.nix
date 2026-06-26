{ config, pkgs, lib, ... }:

let
  mountPoint = "${config.home.homeDirectory}/cloud/probatio/gdrive";
  sharedDrivesBase = "${config.home.homeDirectory}/cloud/probatio/shared";
  
  # List of shared drives found (Knowledge_Base removed to be synced bidirectionally instead)
  sharedDrives = [
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

  # Knowledge Base Bidirectional Sync Configuration
  localKB = "${sharedDrivesBase}/Knowledge_Base";
  remoteKB = "gdrive-probatio,team_drive=0AHK9So00yj9YUk9PVA,root_folder_id=:";
  rcloneConfig = "/run/agenix/rclone-gdrive";

  syncScript = pkgs.writeShellScriptBin "sync-knowledge-base" ''
    set -euo pipefail
    
    # Check if a bisync run is already active
    if [ -f /tmp/kb-sync.lock ]; then
      echo "Sync already running..."
      exit 0
    fi
    touch /tmp/kb-sync.lock
    trap 'rm -f /tmp/kb-sync.lock' EXIT

    # Ensure local directory exists
    mkdir -p "${localKB}"

    # Determine filter rules (create default .rcloneignore if it does not exist)
    IGNORE_FILE="${localKB}/.rcloneignore"
    if [ ! -f "$IGNORE_FILE" ]; then
      echo "Creating default .rcloneignore..."
      cat <<EOF > "$IGNORE_FILE"
# Exclude high-churn Obsidian files
- .obsidian/workspace.json
- .obsidian/cache/**
- .trash/**
- .git/**
EOF
    fi

    echo "Running rclone bisync for Knowledge_Base..."
    
    LOG_FILE="/tmp/kb-sync-run.log"
    
    # Run bisync and capture output to handle first-run / filter-change errors automatically
    set +e
    ${pkgs.rclone}/bin/rclone bisync "${localKB}" "${remoteKB}" \
      --config ${rcloneConfig} \
      --filters-file "$IGNORE_FILE" \
      --conflict-resolve newer \
      --conflict-loser delete \
      --max-delete 50 \
      --verbose > "$LOG_FILE" 2>&1
    EXIT_CODE=$?
    set -e

    cat "$LOG_FILE"

    if [ $EXIT_CODE -ne 0 ]; then
      if grep -q -i -E "must run --resync|filters file md5 hash not found" "$LOG_FILE"; then
        echo "Detected first run or filter change. Running automatic --resync..."
        ${pkgs.rclone}/bin/rclone bisync "${localKB}" "${remoteKB}" \
          --config ${rcloneConfig} \
          --filters-file "$IGNORE_FILE" \
          --conflict-resolve newer \
          --conflict-loser delete \
          --max-delete 50 \
          --resync \
          --verbose
      else
        echo "Sync failed with exit code $EXIT_CODE"
        exit $EXIT_CODE
      fi
    fi
  '';

in {
  home.packages = with pkgs; [ 
    fuse3 
    rclone 
    syncScript
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

    knowledge-base-sync = {
      Unit = {
        Description = "Bidirectional synchronization of Knowledge_Base with Google Drive Shared Drive";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${syncScript}/bin/sync-knowledge-base";
      };
    };
  };

  systemd.user.timers.knowledge-base-sync = {
    Unit = {
      Description = "Timer for Knowledge_Base Google Drive sync";
    };
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
