{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tor-downloader;

  # Embedded Python Scripts
  queueServerPy = pkgs.writeText "queue_server.py" (builtins.readFile ../tor_download_system/queue_server.py);
  sinkCollectorPy = pkgs.writeText "sink_collector.py" (builtins.readFile ../tor_download_system/sink_collector.py);
  torWorkerPy = pkgs.writeText "tor_worker.py" (builtins.readFile ../tor_download_system/tor_worker.py);

  pythonEnv = pkgs.python3.withPackages (ps: [ ps.pysocks ]);
in {
  options.services.tor-downloader = {
    server = {
      enable = mkEnableOption "Tor Downloader Queue Server & Management Web UI (Wieselburg)";
      port = mkOption {
        type = types.port;
        default = 8888;
        description = "Port to listen on for the Queue Coordinator & Web UI";
      };
      domain = mkOption {
        type = types.str;
        default = "tor-downloader.maixnor.com";
        description = "Domain name for Traefik HTTPS reverse proxy";
      };
      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/tor-downloader";
        description = "Data directory for SQLite database and staging files";
      };
      apiKeyFile = mkOption {
        type = types.str;
        default = "/run/secrets/tor-downloader-api-key";
        description = "Path to agenix decrypted API key file";
      };
      initialOnionUrls = mkOption {
        type = types.listOf types.str;
        default = [ "http://klzerfz7xsc7wp3nyik3adffspkkg4lmkeycarsjequnftby4aqsy6qd.onion/data/ALSGLOBAL/" ];
        description = "Initial onion target URLs to seed into the queue";
      };
      openFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to open the server port in firewall";
      };
    };

    sink = {
      enable = mkEnableOption "Tor Downloader Ingestion Sink (Pulls completed files from Wieselburg to local storage)";
      serverUrl = mkOption {
        type = types.str;
        default = "https://tor-downloader.maixnor.com";
        description = "URL of the Tor Downloader Server";
      };
      sourceHost = mkOption {
        type = types.str;
        default = "maixnor.com";
        description = "Remote host (Wieselburg) to rsync completed files from";
      };
      destinationDir = mkOption {
        type = types.str;
        default = "/data/download";
        description = "Local directory where downloaded files land (Bierbasis)";
      };
      apiKeyFile = mkOption {
        type = types.str;
        default = "/run/secrets/tor-downloader-api-key";
        description = "Path to agenix decrypted API key file";
      };
    };

    agent = {
      enable = mkEnableOption "Tor Downloader Worker Agent";
      serverUrl = mkOption {
        type = types.str;
        default = "https://tor-downloader.maixnor.com";
        description = "URL of the Queue Coordinator Server";
      };
      socksProxy = mkOption {
        type = types.str;
        default = "127.0.0.1:9050";
        description = "TOR SOCKS5 proxy address (e.g., 127.0.0.1:9050 or 127.0.0.1:9150)";
      };
      workerId = mkOption {
        type = types.str;
        default = "${config.networking.hostName}-agent";
        description = "Unique identifier for this worker node";
      };
      stagingDir = mkOption {
        type = types.str;
        default = "/var/lib/tor-downloader/staging";
        description = "Directory to stage downloads on this worker before ingestion";
      };
      apiKeyFile = mkOption {
        type = types.str;
        default = "/run/secrets/tor-downloader-api-key";
        description = "Path to agenix decrypted API key file";
      };
    };
  };

  config = mkMerge [
    # SERVER SERVICE CONFIGURATION (e.g. wieselburg)
    (mkIf cfg.server.enable {
      networking.firewall.allowedTCPPorts = mkIf cfg.server.openFirewall [ cfg.server.port ];

      # Automatic Traefik HTTPS reverse proxy configuration
      environment.etc."traefik/tor-downloader-maixnor-com.yml" = mkIf (config.services.traefik.enable or true) {
        text = ''
          http:
            routers:
              tor-downloader-maixnor-com:
                rule: "Host(`${cfg.server.domain}`)"
                service: "tor-downloader-maixnor-com"
                entryPoints:
                  - "websecure"
                tls:
                  certResolver: "letsencrypt"

            services:
              tor-downloader-maixnor-com:
                loadBalancer:
                  servers:
                    - url: "http://127.0.0.1:${toString cfg.server.port}"
        '';
      };

      systemd.services.tor-downloader-server = {
        description = "Tor Downloader Queue Coordinator & Web Management UI";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pythonEnv pkgs.curl pkgs.sqlite ];
        environment = {
          QUEUE_DB_PATH = "${cfg.server.dataDir}/queue.db";
          API_KEY_FILE = cfg.server.apiKeyFile;
        };
        serviceConfig = {
          Type = "simple";
          User = "root";
          ExecStartPre = pkgs.writeShellScript "init-tor-downloader-server" ''
            mkdir -p ${cfg.server.dataDir}/staging
            chmod 755 ${cfg.server.dataDir}
          '';
          ExecStart = "${pythonEnv}/bin/python3 ${queueServerPy} ${toString cfg.server.port}";
          Restart = "always";
          RestartSec = "5s";
        };
      };
    })

    # SINK SERVICE CONFIGURATION (e.g. bierbasis)
    (mkIf cfg.sink.enable {
      systemd.services.tor-downloader-sink = {
        description = "Tor Downloader Ingestion Sink Collector (Bierbasis)";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pythonEnv pkgs.rsync pkgs.openssh pkgs.curl ];
        serviceConfig = {
          Type = "simple";
          User = "root";
          ExecStartPre = pkgs.writeShellScript "init-tor-downloader-sink" ''
            mkdir -p ${cfg.sink.destinationDir}
          '';
          ExecStart = "${pythonEnv}/bin/python3 ${sinkCollectorPy} --server-url ${cfg.sink.serverUrl} --source-host ${cfg.sink.sourceHost} --destination-dir ${cfg.sink.destinationDir} --api-key-file ${cfg.sink.apiKeyFile}";
          Restart = "always";
          RestartSec = "10s";
        };
      };
    })

    # AGENT WORKER SERVICE CONFIGURATION (wieselburg, bierbasis, bierzelt, etc.)
    (mkIf cfg.agent.enable {
      # Automatically enable local TOR client daemon for agent
      services.tor = {
        enable = true;
        client.enable = true;
      };

      systemd.services.tor-downloader-agent = {
        description = "Tor Downloader Worker Agent (${cfg.agent.workerId})";
        after = [ "network.target" "tor.service" ];
        requires = [ "tor.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pythonEnv pkgs.curl pkgs.openssh ];
        serviceConfig = {
          Type = "simple";
          User = "root";
          ExecStartPre = pkgs.writeShellScript "init-tor-downloader-agent" ''
            mkdir -p ${cfg.agent.stagingDir}
          '';
          ExecStart = "${pythonEnv}/bin/python3 ${torWorkerPy} --worker-id ${cfg.agent.workerId} --server-url ${cfg.agent.serverUrl} --socks-proxy ${cfg.agent.socksProxy} --staging-dir ${cfg.agent.stagingDir} --api-key-file ${cfg.agent.apiKeyFile}";
          Restart = "always";
          RestartSec = "5s";
        };
      };
    })
  ];
}
