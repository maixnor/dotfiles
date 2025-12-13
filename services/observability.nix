{ pkgs, config, ... }:

{
  # MONITORING: services run on loopback interface
  #             nginx reverse proxy exposes services to network
  #             - grafana:3000
  #             - prometheus:9090
  #             - loki:3100
  #             - promtail:9080

  # prometheus: port 9090 (default)
  #
  services.prometheus = {
    port = 9090;
    listenAddress = "127.0.0.1";
    enable = true;

    exporters = {
      node = {
        port = 9100;
        enabledCollectors = [ "systemd" ];
        enable = true;
      };
      
      redis = {
        port = 9121;
        enable = true;
      };
    };

    # ingest the published nodes
    scrapeConfigs = [
      {
        job_name = "nodes";
        static_configs = [{
          targets = [
            "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
          ];
        }];
      }
      {
        job_name = "redis";
        static_configs = [{
          targets = [
            "127.0.0.1:${toString config.services.prometheus.exporters.redis.port}"
          ];
        }];
      }
      {
        job_name = "languagebuddy-prod";
        metrics_path = "/metrics";
        static_configs = [{
          targets = [ "127.0.0.1:8080" ];
        }];
      }
      {
        job_name = "languagebuddy-test";
        metrics_path = "/metrics";
        static_configs = [{
          targets = [ "127.0.0.1:8081" ];
        }];
      }
      {
        job_name = "traefik";
        static_configs = [{
          targets = [ "127.0.0.1:8002" ];
        }];
      }
    ];
  };

  # loki: port 3100 (default)
  #
  services.loki = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 3100;
        http_listen_address = "127.0.0.1";
        grpc_listen_port = 9095;
        grpc_listen_address = "127.0.0.1";
      };
      auth_enabled = false;
      
      frontend = {
        address = "127.0.0.1";
      };

      # Disable memberlist for single-node setup
      memberlist = {
        abort_if_cluster_join_fails = false;
        bind_addr = [ "127.0.0.1" ];
        join_members = [];
      };

      common = {
        ring = {
          kvstore = {
            store = "inmemory";
          };
        };
        replication_factor = 1;
        instance_addr = "127.0.0.1";
      };

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 999999;
        chunk_retain_period = "30s";
      };

      schema_config = {
        configs = [{
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "/var/lib/loki/tsdb-shipper-active";
          cache_location = "/var/lib/loki/tsdb-shipper-cache";
          cache_ttl = "24h";
        };

        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };

      compactor = {
        working_directory = "/var/lib/loki/compactor";
        compaction_interval = "10m";
        retention_enabled = false;
        retention_delete_delay = "2h";
        retention_delete_worker_count = 150;
        compactor_ring = {
          kvstore = {
            store = "inmemory";
          };
        };
      };
    };
    # user, group, dataDir, extraFlags, (configFile)
  };

  # promtail: port 9080 (default)
  #
  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };
      positions = {
        filename = "/tmp/positions.yaml";
      };
      clients = [{
        url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
      }];
      scrape_configs = [{
        job_name = "journal";
        journal = {
          max_age = "12h";
          labels = {
            job = "systemd-journal";
            host = "pihole";
          };
        };
        relabel_configs = [{
          source_labels = [ "__journal__systemd_unit" ];
          target_label = "unit";
        }];
      }];
    };
    # extraFlags
  };

  # tempo: port 3200 (default)
  #
  services.tempo = {
    enable = true;
    settings = {
      server = {
        http_listen_port = 3200;
        http_listen_address = "127.0.0.1";
        grpc_listen_port = 9096;
        grpc_listen_address = "127.0.0.1";
      };

      memberlist = {
        abort_if_cluster_join_fails = false;
        bind_port = 7947;
        bind_addr = ["127.0.0.1"];
        advertise_addr = "127.0.0.1";
        advertise_port = 7947;
        join_members = [];
      };

      auth_enabled = false;
      
      distributor = {
        receivers = {
          otlp = {
            protocols = {
              grpc = {
                endpoint = "127.0.0.1:4317";
              };
              http = {
                endpoint = "127.0.0.1:4318";
              };
            };
          };
        };
      };

      ingester = {
        lifecycler = {
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
          tokens_file_path = "/var/lib/tempo/tokens.json";
          address = "127.0.0.1";
        };
        trace_idle_period = "10s";
        max_block_bytes = 1000000;
        max_block_duration = "5m";
      };

      compactor = {
        compaction = {
          block_retention = "1h";
        };
        ring = {
          kvstore = {
            store = "inmemory";
          };
          instance_addr = "127.0.0.1";
        };
      };

      metrics_generator = {
        ring = {
          kvstore = {
            store = "inmemory";
          };
          instance_addr = "127.0.0.1";
        };
        processor = {
          service_graphs = {
            dimensions = ["service.name"];
          };
          span_metrics = {
            dimensions = ["service.name"];
          };
          local_blocks = {
            filter_server_spans = false;
          };
        };
        storage = {
          path = "/var/lib/tempo/generator/wal";
          remote_write = [
            {
              url = "http://127.0.0.1:9090/api/v1/write";
              send_exemplars = true;
            }
          ];
        };
      };

      storage = {
        trace = {
          backend = "local";
          wal = {
            path = "/var/lib/tempo/wal";
          };
          local = {
            path = "/var/lib/tempo/blocks";
          };
        };
      };

      overrides = {
        defaults = {
          metrics_generator = {
            processors = ["service-graphs" "span-metrics" "local-blocks"];
          };
        };
      };
    };
  };

  # grafana: port 3000 (default)
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_port = 3000;
        root_url = "https://grafana.maixnor.com";
        protocol = "http";
        http_addr = "127.0.0.1";
      };

      database = {
        type = "sqlite3";
        path = "/var/lib/grafana/grafana.db";
      };
      
      security = {
        admin_user = "admin";
        admin_password = "$__file{/etc/grafana.scrt}";
        secret_key = "$__file{/etc/grafana.key}";
      };
      
      analytics = {
        reporting_enabled = true;
      };
      
      users = {
        allow_sign_up = false;
        allow_org_create = false;
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          uid = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          isDefault = true;
          jsonData = {
            httpMethod = "POST";
            timeInterval = "15s";
            queryTimeout = "60s";
          };
        }
        {
          name = "Loki";
          type = "loki";
          uid = "loki";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          jsonData = {
            maxLines = 1000;
          };
        }
        {
          name = "Tempo";
          type = "tempo";
          uid = "tempo";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.tempo.settings.server.http_listen_port}";
          jsonData = {
            httpMethod = "GET";
            nodeGraph = {
              enabled = true;
            };
            search = {
              hide = false;
            };
          };
        }
      ];
    };
  };

  # Create Traefik configuration for observability services
  environment.etc."traefik/observability.yml".text = ''
    http:
      routers:
        grafana:
          rule: "Host(`grafana.maixnor.com`)"
          service: "grafana"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
        
        prometheus:
          rule: "Host(`prometheus.maixnor.com`)"
          service: "prometheus"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
          middlewares:
            - "auth"
        
        loki:
          rule: "Host(`loki.maixnor.com`)"
          service: "loki"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
          middlewares:
            - "auth"
        
        tempo:
          rule: "Host(`tempo.maixnor.com`)"
          service: "tempo"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"
          middlewares:
            - "auth"

      services:
        grafana:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}"
        
        prometheus:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:${toString config.services.prometheus.port}"
        
        loki:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}"
        
        tempo:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:${toString config.services.tempo.settings.server.http_listen_port}"

      middlewares:
        auth:
          basicAuth:
            usersFile: "/etc/observability.scrt"
  '';

        # Create some basic Grafana dashboards
    environment.etc."grafana/dashboards/system-overview.json".text = builtins.toJSON {
      dashboard = {
        id = null;
        title = "System Overview";
        tags = [ "system" "overview" ];
        timezone = "browser";
        panels = [
          {
            id = 1;
            title = "CPU Usage";
            type = "graph";
            targets = [
              {
                expr = "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
                legendFormat = "CPU Usage - {{instance}}";
              }
              {
                expr = "avg by (mode) (irate(node_cpu_seconds_total[5m])) * 100";
                legendFormat = "{{mode}}";
              }
            ];
            gridPos = { h = 8; w = 12; x = 0; y = 0; };
            fieldConfig = {
              defaults = {
                unit = "percent";
                min = 0;
                max = 100;
              };
            };
          }
          {
            id = 2;
            title = "Memory Usage";
            type = "graph";
            targets = [
              {
                expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
                legendFormat = "Memory Usage %";
              }
              {
                expr = "node_memory_MemTotal_bytes";
                legendFormat = "Total Memory";
              }
              {
                expr = "node_memory_MemAvailable_bytes";
                legendFormat = "Available Memory";
              }
            ];
            gridPos = { h = 8; w = 12; x = 12; y = 0; };
            fieldConfig = {
              defaults = {
                unit = "percent";
                min = 0;
                max = 100;
              };
            };
          }
          {
            id = 4;
            title = "Redis Stats";
            type = "graph";
            targets = [
              {
                expr = "redis_connected_clients";
                legendFormat = "Connected Clients";
              }
              {
                expr = "rate(redis_commands_processed_total[5m])";
                legendFormat = "Commands/sec";
              }
              {
                expr = "redis_memory_used_bytes";
                legendFormat = "Memory Used";
              }
            ];
            gridPos = { h = 8; w = 12; x = 0; y = 16; };
          }
          {
            id = 5;
            title = "System Memory Details";
            type = "graph";
            targets = [
              {
                expr = "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes";
                legendFormat = "Used Memory";
              }
              {
                expr = "node_memory_Buffers_bytes";
                legendFormat = "Buffers";
              }
              {
                expr = "node_memory_Cached_bytes";
                legendFormat = "Cached";
              }
              {
                expr = "node_memory_MemFree_bytes";
                legendFormat = "Free";
              }
            ];
            gridPos = { h = 8; w = 12; x = 12; y = 16; };
            fieldConfig = {
              defaults = {
                unit = "bytes";
              };
            };
          }
          {
            id = 3;
            title = "LanguageBuddy Response Times";
            type = "graph";
            targets = [
              {
                expr = "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service=\"languagebuddy\"}[5m])) by (le, environment))";
                legendFormat = "95th percentile - {{environment}}";
              }
              {
                expr = "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{service=\"languagebuddy\"}[5m])) by (le, environment))";
                legendFormat = "50th percentile - {{environment}}";
              }
            ];
            gridPos = { h = 8; w = 24; x = 0; y = 8; };
          }
        ];
        time = {
          from = "now-1h";
          to = "now";
        };
        refresh = "5s";
      };
    };
  
    # Explicitly provision an empty list for "local" datasources to ensure any previously
    # provisioned datasources from such a file (if they existed) are removed.
    environment.etc."grafana/provisioning/datasources/00-local-datasources.yaml".text = ''
      apiVersion: 1
  
      datasources: []
    '';
  
    # Open firewall ports for internal services  networking.firewall.allowedTCPPorts = [ 3000 9090 3100 9080 9100 9121 3200 ];

  # Create data directories
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana 0755 grafana grafana -"
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    "d /var/lib/loki 0755 loki loki -"
    "d /var/lib/loki/chunks 0755 loki loki -"
    "d /var/lib/loki/tsdb-shipper-active 0755 loki loki -"
    "d /var/lib/loki/tsdb-shipper-cache 0755 loki loki -"
    "d /var/lib/loki/compactor 0755 loki loki -"
    "d /var/lib/promtail 0755 promtail promtail -"
    "d /var/lib/tempo 0755 tempo tempo -"
    "d /var/lib/tempo/blocks 0755 tempo tempo -"
    "d /var/lib/tempo/wal 0755 tempo tempo -"
    "d /var/lib/tempo/generator 0755 tempo tempo -"
    "d /var/lib/tempo/generator/wal 0755 tempo tempo -"
    # Fix permissions on Grafana config files (existing or new)
    "z /etc/grafana.scrt 0640 grafana grafana -"
    "z /etc/grafana.key 0640 grafana grafana -"
    # Fix permissions on observability auth file (must be readable by traefik)
    "z /etc/observability.scrt 0644 root root -"
  ];
}
