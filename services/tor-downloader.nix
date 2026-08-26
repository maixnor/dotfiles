{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tor-downloader;

  pythonEnv = pkgs.python3.withPackages (ps: [ ps.pysocks ps.aiohttp ps.aiofiles ]);
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

    agent = {
      enable = mkEnableOption "Tor Downloader Worker Agent";
      serverUrl = mkOption {
        type = types.str;
        default = "https://tor-downloader.maixnor.com";
        description = "URL of the Queue Coordinator Server";
      };
      workerCount = mkOption {
        type = types.int;
        default = 50;
        description = "Number of parallel Tor downloader worker processes and SOCKS proxy ports to spawn (50 sessions)";
      };
      baseSocksPort = mkOption {
        type = types.port;
        default = 9100;
        description = "Base SOCKS5 port for Tor client proxies (9100..9149)";
      };
      socksProxy = mkOption {
        type = types.str;
        default = "127.0.0.1:9050";
        description = "TOR SOCKS5 proxy address";
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
          LimitNOFILE = 65536;
          ExecStartPre = pkgs.writeShellScript "init-tor-downloader-server" ''
            mkdir -p ${cfg.server.dataDir}/staging
            chmod 755 ${cfg.server.dataDir}
            chmod -R u+rwX,go+rwX ${cfg.server.dataDir} 2>/dev/null || true
          '';
          ExecStart = "${pythonEnv}/bin/python3 ${../tor_download_system}/queue_server.py ${toString cfg.server.port}";
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
        environment = {
          HOME = "/home/maixnor";
        };
        serviceConfig = {
          Type = "simple";
          User = "maixnor";
          LimitNOFILE = 65536;
          ExecStartPre = pkgs.writeShellScript "init-tor-downloader-sink" ''
            mkdir -p ${cfg.sink.destinationDir}
          '';
          ExecStart = "${pythonEnv}/bin/python3 ${../tor_download_system}/sink_collector.py --server-url ${cfg.sink.serverUrl} --source-host ${cfg.sink.sourceHost} --ssh-key ${cfg.sink.sshKey} --destination-dir ${cfg.sink.destinationDir} --api-key-file ${cfg.sink.apiKeyFile}";
          Restart = "always";
          RestartSec = "10s";
        };
      };
    })

    # AGENT WORKER SERVICE CONFIGURATION (wieselburg, bierbasis, bierzelt, etc.)
    (mkIf cfg.agent.enable {
      # Automatically enable local TOR client daemon with multi-SOCKS port bindings (9100..9149)
      services.tor = {
        enable = true;
        client.enable = true;
        settings = {
          SocksPort = map (i: "127.0.0.1:${toString (cfg.agent.baseSocksPort + i)} IsolateDestAddr IsolateDestPort SessionGroup=${toString i}") (lib.range 0 (cfg.agent.workerCount - 1));
          NumEntryGuards = 8;
          MaxCircuitDirtiness = 30;
          CircuitBuildTimeout = 15;
          KeepalivePeriod = 20;
          EnforceDistinctSubnets = true;
        };
      };

      systemd.services = builtins.listToAttrs (map (i: {
        name = "tor-downloader-agent-${toString (i + 1)}";
        value = {
          description = "Tor Downloader Worker Agent (${cfg.agent.workerId}-${toString (i + 1)})";
          after = [ "network.target" "tor.service" ];
          requires = [ "tor.service" ];
          wantedBy = [ "multi-user.target" ];
          path = [ pythonEnv pkgs.curl pkgs.openssh ];
          serviceConfig = {
            Type = "simple";
            User = "root";
            LimitNOFILE = 65536;
            ExecStartPre = pkgs.writeShellScript "init-tor-downloader-agent-${toString (i + 1)}" ''
              mkdir -p ${cfg.agent.stagingDir}
              find ${cfg.agent.stagingDir} -maxdepth 2 -type f ! -name "*.*" -delete 2>/dev/null || true
            '';
            Environment = [ "PYTHONUNBUFFERED=1" ];
            ExecStart = "${pythonEnv}/bin/python3 ${../tor_download_system}/tor_worker.py --worker-id ${cfg.agent.workerId}-${toString (i + 1)} --server-url ${cfg.agent.serverUrl} --socks-proxy 127.0.0.1:${toString (cfg.agent.baseSocksPort + i)} --staging-dir ${cfg.agent.stagingDir} --api-key-file ${cfg.agent.apiKeyFile}${lib.optionalString cfg.sink.enable " --destination-dir ${cfg.sink.destinationDir}"}";
            Restart = "always";
            RestartSec = "5s";
          };
        };
      }) (lib.range 0 (cfg.agent.workerCount - 1)));
    })
  ];
}
