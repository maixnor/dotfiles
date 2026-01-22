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
    # empty for now because I don't exactly how to publish to my blog site :)
  '';

  # Ensure the windmill group exists and maixnor is a member
  users.groups.windmill = {};
  users.users.maixnor.extraGroups = [ "windmill" ];

  # Satisfy NixOS user assertions for the windmill service user
  users.users.windmill = {
    isSystemUser = true;
    group = "windmill";
  };

  # Satisfy NixOS user assertions for the content-factory service user
  users.groups.content_factory = {};
  users.users.content_factory = {
    isSystemUser = true;
    group = "content_factory";
    extraGroups = [ "windmill" ]; # Might need access to shared secrets/files
  };

  # 5. Secrets (Single .env file)
  age.secrets."content-factory.env" = {
    file = ../secrets/content-factory.env.age;
    owner = "windmill";
    group = "windmill";
    mode = "0440";
  };

  # 6. Windmill Environment Fixes
  systemd.services.windmill-server.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "windmill";
    Group = "windmill";
    Environment = [ "PYTHONPATH=${contentFactory.maya-package}/${pkgs.python312.sitePackages}" ];
    EnvironmentFile = [ config.age.secrets."content-factory.env".path ];
  };

  # Create a python environment with the maya package included
  # This is the "clean" way: Windmill will see these as pre-installed system packages
  systemd.services.windmill-worker.serviceConfig = let
    py3 = pkgs.python312;
    maya-pkg = contentFactory.maya-package;
    mayaPython = py3.withPackages (ps: [ 
      maya-pkg
      ps.psycopg2
    ]);
  in {
    DynamicUser = lib.mkForce false;
    User = "windmill";
    Group = "windmill";
    Environment = [ 
      "PATH=${mayaPython}/bin:${pkgs.lib.makeBinPath [ py3 pkgs.curl pkgs.jq ]}"
      "PYTHONPATH=${maya-pkg}/${py3.sitePackages}"
      "WM_PYTHON_SKIP_RESOLVE=windmill_scripts,orchestrator,publisher,models,blog_engine,image_gen,persona,researcher,main,utils,scraper,ai_transformer,approval_flow,approval_logic,image_generator,list_models,windmill_trigger"
    ];
    EnvironmentFile = [ config.age.secrets."content-factory.env".path ];
  };

  systemd.services.windmill-worker-native.serviceConfig = let
    py3 = pkgs.python312;
    maya-pkg = contentFactory.maya-package;
    mayaPython = py3.withPackages (ps: [ 
      maya-pkg
    ]);
  in {
    DynamicUser = lib.mkForce false;
    User = "windmill";
    Group = "windmill";
    Environment = [ 
      "PATH=${mayaPython}/bin:${pkgs.lib.makeBinPath [ py3 pkgs.curl pkgs.jq ]}"
      "PYTHONPATH=${maya-pkg}/${py3.sitePackages}"
      "WM_PYTHON_SKIP_RESOLVE=windmill_scripts,orchestrator,publisher,models,blog_engine,image_gen,persona,researcher,main,utils,scraper,ai_transformer,approval_flow,approval_logic,image_generator,list_models,windmill_trigger"
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
