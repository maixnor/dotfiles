{ config, pkgs, lib, ... }:

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

  # The native service handles the worker and server setup automatically.
  # We just need to ensure the database exists (handled in step 1).

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
    
    # Ensure the repo itself is readable by the group
    chmod g+x /home/maixnor
    chmod -R g+rX /home/maixnor/repo/dotfiles
    
    if id "windmill" >/dev/null 2>&1; then
      usermod -a -G maixnor windmill
    fi
  '';

  # 5. Windmill Environment
  let
    # This derivation "deploys" your scripts into the Nix store
    content-factory-src = pkgs.stdenv.mkDerivation {
      name = "content-factory-src";
      src = ../content-factory;
      installPhase = ''
        mkdir -p $out
        cp -rv $src/* $out/
      '';
    };

    cf-python = pkgs.python3.withPackages (ps: with ps; [
      alembic
      sqlalchemy
      psycopg2
      beautifulsoup4
      httpx
      google-genai
      pillow
    ]);
  in {
    systemd.services.windmill-server.serviceConfig.Environment = [
      "PYTHONPATH=${content-factory-src}"
      "PATH=${lib.makeBinPath [ cf-python ]}:/run/current-system/sw/bin"
    ];
    systemd.services.windmill-worker.serviceConfig.Environment = [
      "PYTHONPATH=${content-factory-src}"
      "PATH=${lib.makeBinPath [ cf-python ]}:/run/current-system/sw/bin"
      # Tell Windmill not to try and resolve these local modules via PyPI
      "WM_PYTHON_SKIP_RESOLVE=windmill_scripts,orchestrator,publisher,models,blog_engine,image_gen,persona,researcher"
    ];
    systemd.services.windmill-worker-native.serviceConfig.Environment = [
      "PYTHONPATH=${content-factory-src}"
      "PATH=${lib.makeBinPath [ cf-python ]}:/run/current-system/sw/bin"
      "WM_PYTHON_SKIP_RESOLVE=windmill_scripts,orchestrator,publisher,models,blog_engine,image_gen,persona,researcher"
    ];
  };

  # 5. Publisher Service (Now just a helper, triggers moved to Windmill)
  systemd.services.maya-publisher = {
    description = "Publish scheduled Maya blog posts";
    serviceConfig = {
      Type = "oneshot";
      User = "maixnor";
      WorkingDirectory = "/home/maixnor/repo/dotfiles/content-factory";
      ExecStart = "${pkgs.nix}/bin/nix-shell /home/maixnor/repo/dotfiles/content-factory/shell.nix --run 'python3 publisher.py'";
    };
    environment = {
      DATABASE_URL = "postgresql://content_factory@localhost:5432/content_factory";
    };
  };
}
