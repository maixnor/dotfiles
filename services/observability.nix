{ pkgs, ... }:

{
  # Prometheus for metrics collection
  services.prometheus = {
    enable = true;
    port = 9090;
    
    # Prometheus configuration
    exporters = {
      # Node exporter for system metrics
      node = {
        enable = true;
        port = 9100;
        enabledCollectors = [
          "systemd"
          "processes"
          "interrupts"
          "conntrack"
          "diskstats"
          "entropy"
          "filefd"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "netstat"
          "stat"
          "time"
          "vmstat"
          "logind"
          "textfile"
        ];
      };
      
      # Redis exporter for Redis metrics
      redis = {
        enable = true;
        port = 9121;
        extraFlags = [
          "--redis.addr=redis://localhost:6380"
          "--redis.password-file=/etc/languagebuddy-prod.scrt"
        ];
      };
    };
    
    # Scrape configuration
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [{
          targets = [ "localhost:9090" ];
        }];
      }
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
        }];
        scrape_interval = "15s";
      }
      {
        job_name = "redis-prod";
        static_configs = [{
          targets = [ "localhost:9121" ];
        }];
        relabel_configs = [{
          target_label = "environment";
          replacement = "prod";
        }];
      }
      {
        job_name = "languagebuddy-prod";
        static_configs = [{
          targets = [ "localhost:8080" ];
        }];
        metrics_path = "/metrics";
        scrape_interval = "30s";
        relabel_configs = [{
          target_label = "environment";
          replacement = "prod";
        } {
          target_label = "service";
          replacement = "languagebuddy";
        }];
      }
      {
        job_name = "languagebuddy-test";
        static_configs = [{
          targets = [ "localhost:8081" ];
        }];
        metrics_path = "/metrics";
        scrape_interval = "30s";
        relabel_configs = [{
          target_label = "environment";
          replacement = "test";
        } {
          target_label = "service";
          replacement = "languagebuddy";
        }];
      }
    ];
    
    # Global configuration
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };
  };

  # Loki for log aggregation
  services.loki = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 3100;
      };
      
      auth_enabled = false;
      
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
      };
      
      schema_config = {
        configs = [{
          from = "2020-10-24";
          store = "boltdb-shipper";
          object_store = "filesystem";
          schema = "v11";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };
      
      storage_config = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/boltdb-shipper-active";
          cache_location = "/var/lib/loki/boltdb-shipper-cache";
        };
        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };
      
      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };
    };
  };

  # Promtail for log shipping to Loki
  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };
      
      positions = {
        filename = "/var/lib/promtail/positions.yaml";
      };
      
      clients = [{
        url = "http://localhost:3100/loki/api/v1/push";
      }];
      
      scrape_configs = [
        # Systemd journal logs
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "maixnor-server";
            };
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
            {
              source_labels = [ "__journal_priority" ];
              target_label = "priority";
            }
            {
              source_labels = [ "__journal__hostname" ];
              target_label = "hostname";
            }
            # Add environment labels for languagebuddy services
            {
              source_labels = [ "__journal__systemd_unit" ];
              regex = "languagebuddy-api-prod.service";
              target_label = "environment";
              replacement = "prod";
            }
            {
              source_labels = [ "__journal__systemd_unit" ];
              regex = "languagebuddy-api-test.service";
              target_label = "environment";
              replacement = "test";
            }
            {
              source_labels = [ "__journal__systemd_unit" ];
              regex = "languagebuddy.*";
              target_label = "service";
              replacement = "languagebuddy";
            }
          ];
        }
        # Additional log files if needed
        {
          job_name = "var-log";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              job = "varlogs";
              host = "maixnor-server";
              __path__ = "/var/log/*.log";
            };
          }];
        }
      ];
    };
  };

  # Grafana for visualization
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        domain = "grafana.maixnor.com";
        root_url = "https://grafana.maixnor.com";
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
        reporting_enabled = false;
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
          access = "proxy";
          url = "http://localhost:9090";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://localhost:3100";
        }
      ];
      
      dashboards.settings.providers = [{
        name = "default";
        orgId = 1;
        folder = "";
        type = "file";
        disableDeletion = false;
        updateIntervalSeconds = 10;
        allowUiUpdates = true;
        options.path = "/var/lib/grafana/dashboards";
      }];
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

      services:
        grafana:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:3000"
        
        prometheus:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:9090"
        
        loki:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:3100"

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
          type = "stat";
          targets = [{
            expr = "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
            legendFormat = "CPU Usage %";
          }];
          gridPos = { h = 8; w = 12; x = 0; y = 0; };
        }
        {
          id = 2;
          title = "Memory Usage";
          type = "stat";
          targets = [{
            expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
            legendFormat = "Memory Usage %";
          }];
          gridPos = { h = 8; w = 12; x = 12; y = 0; };
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

  # Open firewall ports for internal services
  networking.firewall.allowedTCPPorts = [ 9090 3100 3000 ];

  # Create data directories
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana 0755 grafana grafana -"
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    "d /var/lib/loki 0755 loki loki -"
    "d /var/lib/loki/chunks 0755 loki loki -"
    "d /var/lib/loki/boltdb-shipper-active 0755 loki loki -"
    "d /var/lib/loki/boltdb-shipper-cache 0755 loki loki -"
    "d /var/lib/promtail 0755 promtail promtail -"
  ];
}
