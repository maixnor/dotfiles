{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.distributed-downloader;

  # Embedded Python Scripts
  queueServerPy = pkgs.writeText "queue_server.py" (builtins.readFile ../tor_download_system/queue_server.py);
  directWorkerPy = pkgs.writeText "direct_worker.py" (builtins.readFile ../tor_download_system/direct_worker.py);
  sinkCollectorPy = pkgs.writeText "sink_collector.py" (builtins.readFile ../tor_download_system/sink_collector.py);

  pythonEnv = pkgs.python3.withPackages (ps: [ ps.aiohttp ps.aiofiles ps.pysocks ]);
in {
  options.services.distributed-downloader = {
    server = {
      enable = mkEnableOption "Distributed Downloader Queue Server & Management Web UI";
      port = mkOption {
        type = types.port;
        default = 8888;
        description = "Port to listen on for the Queue Coordinator & Web UI";
      };
      domain = mkOption {
        type = types.str;
        default = "downloader.maixnor.com";
        description = "Domain name for Traefik HTTPS reverse proxy";
      };
      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/distributed-downloader";
        description = "Data directory for SQLite database and staging files";
      };
      apiKeyFile = mkOption {
        type = types.str;
        default = "/run/secrets/tor-downloader-api-key";
        description = "Path to agenix decrypted API key file";
      };
      openFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to open the server port in firewall";
      };
    };

    agent = {
      enable = mkEnableOption "High-Concurrency Async Downloader Agent (1k+ Streams)";
      serverUrl = mkOption {
        type = types.str;
        default = "https://tor-downloader.maixnor.com";
        description = "URL of the Queue Coordinator Server";
      };
      concurrency = mkOption {
        type = types.int;
        default = 1000;
        description = "Number of simultaneous async download streams";
      };
      chunkSize = mkOption {
        type = types.int;
        default = 65536;
        description = "Chunk size in bytes for streaming disk writes";
      };
      directCompletion = mkOption {
        type = types.bool;
        default = true;
        description = "Mark tasks completed directly (no rsync staging hop needed if downloading to local destination)";
      };
      outputDir = mkOption {
        type = types.str;
        default = "/data/download";
        description = "Destination directory to write downloaded files";
      };
      workerId = mkOption {
        type = types.str;
        default = "${config.networking.hostName}-direct-1";
        description = "Unique identifier for this worker node";
      };
      apiKeyFile = mkOption {
        type = types.str;
        default = "/run/secrets/tor-downloader-api-key";
        description = "Path to agenix decrypted API key file";
      };
    };

    sink = {
      enable = mkEnableOption "Optional Ingestion Sink (Pulls completed files from remote host to local storage)";
      serverUrl = mkOption {
        type = types.str;
        default = "https://tor-downloader.maixnor.com";
        description = "URL of the Queue Server";
      };
      sourceHost = mkOption {
        type = types.str;
        default = "maixnor.com";
        description = "Remote host to rsync completed files from";
      };
      destinationDir = mkOption {
        type = types.str;
        default = "/data/download";
        description = "Local directory where downloaded files land";
      };
      sshKey = mkOption {
        type = types.str;
        default = "/home/maixnor/.ssh/id_tor_downloader";
        description = "Dedicated SSH private key file for rsync authentication";
      };
      apiKeyFile = mkOption {
        type = types.str;
        default = "/run/secrets/tor-downloader-api-key";
        description = "Path to agenix decrypted API key file";
      };
    };
  };

  config = mkMerge [
    # COORDINATOR SERVER CONFIGURATION
    (mkIf cfg.server.enable {
      networking.firewall.allowedTCPPorts = mkIf cfg.server.openFirewall [ cfg.server.port ];

      environment.etc."traefik/distributed-downloader.yml" = mkIf (config.services.traefik.enable or true) {
        text = ''
          http:
            routers:
              distributed-downloader:
                rule: "Host(`${cfg.server.domain}`)"
                service: "distributed-downloader"
                entryPoints:
                  - "websecure"
                tls:
                  certResolver: "letsencrypt"

            services:
              distributed-downloader:
                loadBalancer:
                  servers:
                    - url: "http://127.0.0.1:${toString cfg.server.port}"
        '';
      };

      systemd.services.distributed-downloader-server = {
        description = "Distributed Downloader Queue Coordinator & Web Management UI";
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
          ExecStartPre = pkgs.writeShellScript "init-distributed-downloader-server" ''
            mkdir -p ${cfg.server.dataDir}
            chmod 755 ${cfg.server.dataDir}
          '';
          ExecStart = "${pythonEnv}/bin/python3 ${queueServerPy} ${toString cfg.server.port}";
          Restart = "always";
          RestartSec = "5s";
        };
      };
    })

    # HIGH-CONCURRENCY ASYNC AGENT (1k Streams, File Handle Pooling)
    (mkIf cfg.agent.enable {
      systemd.services.distributed-downloader-agent = {
        description = "Distributed Async Downloader Agent (${cfg.agent.workerId} - ${toString cfg.agent.concurrency} Streams)";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pythonEnv pkgs.curl ];
        serviceConfig = {
          Type = "simple";
          User = "root";
          # Raise open file descriptor limits for 1,000+ simultaneous TCP streams and file handles
          LimitNOFILE = 1048576;
          ExecStartPre = pkgs.writeShellScript "init-distributed-downloader-agent" ''
            mkdir -p ${cfg.agent.outputDir}
          '';
          ExecStart = "${pythonEnv}/bin/python3 ${directWorkerPy} --worker-id ${cfg.agent.workerId} --server-url ${cfg.agent.serverUrl} --concurrency ${toString cfg.agent.concurrency} --chunk-size ${toString cfg.agent.chunkSize} --output-dir ${cfg.agent.outputDir} ${lib.optionalString cfg.agent.directCompletion "--direct-completion"} --api-key-file ${cfg.agent.apiKeyFile}";
          Restart = "always";
          RestartSec = "5s";
        };
      };
    })

    # OPTIONAL SINK (For Multi-Node setups)
    (mkIf cfg.sink.enable {
      systemd.services.distributed-downloader-sink = {
        description = "Distributed Downloader Ingestion Sink Collector";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pythonEnv pkgs.rsync pkgs.openssh pkgs.curl ];
        environment = {
          HOME = "/home/maixnor";
        };
        serviceConfig = {
          Type = "simple";
          User = "maixnor";
          LimitNOFILE = 65536;
          ExecStartPre = pkgs.writeShellScript "init-distributed-downloader-sink" ''
            mkdir -p ${cfg.sink.destinationDir}
          '';
          ExecStart = "${pythonEnv}/bin/python3 ${sinkCollectorPy} --server-url ${cfg.sink.serverUrl} --source-host ${cfg.sink.sourceHost} --ssh-key ${cfg.sink.sshKey} --destination-dir ${cfg.sink.destinationDir} --api-key-file ${cfg.sink.apiKeyFile}";
          Restart = "always";
          RestartSec = "10s";
        };
      };
    })
  ];
}
