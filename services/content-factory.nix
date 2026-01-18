{ config, pkgs, lib, contentFactory, ... }:

{
  # 1. PostgreSQL Standalone Instance
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "content_factory" "windmill" ];
    ensureUsers = [
      {
        name = "content_factory";
        ensureDBOwnership = true;
      }
      {
        name = "windmill";
        ensureDBOwnership = true;
      }
    ];
    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
    '';
  };

  # 2. Windmill (Native NixOS Service)
  services.windmill = {
    enable = true;
    database.url = "postgres://windmill@localhost:5432/windmill?sslmode=disable";
    serverPort = 8001;
  };

  # 3. Traefik Configuration for Windmill
  environment.etc."traefik/windmill.yml".text = ''
    http:
      routers:
        windmill:
          rule: "Host(`windmill.maixnor.com`)"
          service: "windmill"
          entryPoints:
            - "websecure"
          tls:
            certResolver: "letsencrypt"

      services:
        windmill:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8001"
  '';

  # 4. Content Factory Environment Setup
  system.activationScripts.content-factory-setup = ''
    mkdir -p /var/lib/content-factory/assets
    mkdir -p /var/www/maixnor.com/maya-blog
    
    # Grant permissions to both maixnor and the windmill user
    chown -R maixnor:maixnor /var/lib/content-factory /var/www/maixnor.com/maya-blog
    chmod -R 775 /var/lib/content-factory /var/www/maixnor.com/maya-blog
  '';

  # Declaratively add windmill user to maixnor group
  users.users.windmill.extraGroups = [ "maixnor" ];

  # 5. Secrets (Single .env file)
  age.secrets."content-factory.env" = {
    file = ../secrets/content-factory.env.age;
    owner = "windmill";
    group = "maixnor";
  };

  # 6. Windmill Environment Fixes
  systemd.services.windmill-server.serviceConfig = {
    Environment = [ "PYTHONPATH=${contentFactory.cf-src}" ];
    EnvironmentFile = [ config.age.secrets."content-factory.env".path ];
  };
  systemd.services.windmill-worker.serviceConfig = {
    Environment = [ 
      "PYTHONPATH=${contentFactory.cf-src}"
      "WM_PYTHON_SKIP_RESOLVE=windmill_scripts,orchestrator,publisher,models,blog_engine,image_gen,persona,researcher"
    ];
    EnvironmentFile = [ config.age.secrets."content-factory.env".path ];
  };
  systemd.services.windmill-worker-native.serviceConfig = {
    Environment = [ 
      "PYTHONPATH=${contentFactory.cf-src}"
      "WM_PYTHON_SKIP_RESOLVE=windmill_scripts,orchestrator,publisher,models,blog_engine,image_gen,persona,researcher"
    ];
    EnvironmentFile = [ config.age.secrets."content-factory.env".path ];
  };

  # 7. Database Migrations
  systemd.services.content-factory-migrate = {
    description = "Run database migrations for Content Factory";
    wantedBy = [ "multi-user.target" ];
    after = [ "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "content_factory";
      ExecStart = "${contentFactory.maya-migrate}/bin/maya-migrate";
      EnvironmentFile = [ config.age.secrets."content-factory.env".path ];
      RemainAfterExit = true;
    };
  };

  # 8. Publisher Service
  systemd.services.maya-publisher = {
    description = "Publish scheduled Maya blog posts";
    serviceConfig = {
      Type = "oneshot";
      User = "maixnor";
      ExecStart = "${contentFactory.maya-publish}/bin/maya-publish";
      EnvironmentFile = [ config.age.secrets."content-factory.env".path ];
    };
  };
}
