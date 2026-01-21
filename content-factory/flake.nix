{
  description = "LanguageBuddy Content Factory";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        cf-python = pkgs.python3.withPackages (ps: with ps; [
          alembic
          sqlalchemy
          psycopg2
          beautifulsoup4
          httpx
          google-genai
          pillow
        ]);

        maya-package = pkgs.python3Packages.buildPythonApplication {
          pname = "maya-content-factory";
          version = "0.1.0";
          src = ./.;
          format = "other"; # It's not a standard setup.py project yet

          propagatedBuildInputs = with pkgs.python3Packages; [
            alembic
            sqlalchemy
            psycopg2
            beautifulsoup4
            httpx
            google-genai
            pillow
          ];

          # We just need to wrap the entry points
          installPhase = ''
            mkdir -p $out/${pkgs.python3.sitePackages}
            cp -r . $out/${pkgs.python3.sitePackages}/
            
            mkdir -p $out/bin
            
            makeWrapper ${cf-python}/bin/python3 $out/bin/maya-cli \
              --add-flags "$out/${pkgs.python3.sitePackages}/main.py" \
              --set PYTHONPATH "$out/${pkgs.python3.sitePackages}" \
              --set MONTSERRAT_FONT "${pkgs.montserrat}/share/fonts/otf/Montserrat-Bold.otf"

            makeWrapper ${cf-python}/bin/python3 $out/bin/maya-publish \
              --add-flags "$out/${pkgs.python3.sitePackages}/publisher.py" \
              --set PYTHONPATH "$out/${pkgs.python3.sitePackages}"

            makeWrapper ${cf-python}/bin/alembic $out/bin/maya-migrate \
              --add-flags "upgrade head" \
              --set PYTHONPATH "$out/${pkgs.python3.sitePackages}" \
              --run "cd $out/${pkgs.python3.sitePackages}"
          '';

          nativeBuildInputs = [ pkgs.makeWrapper ];
        };

        cf-src = ./.;

        maya-cli = pkgs.writeShellScriptBin "maya-cli" ''
          export PYTHONPATH="${cf-src}:$PYTHONPATH"
          export MONTSERRAT_FONT="${pkgs.montserrat}/share/fonts/opentype/Montserrat-Bold.otf"
          
          # Load secrets if they exist
          if [ -f /run/secrets/content-factory.env ]; then
            set -a; source /run/secrets/content-factory.env; set +a
          fi
          exec ${cf-python}/bin/python3 ${cf-src}/main.py "$@"
        '';

        maya-publish = pkgs.writeShellScriptBin "maya-publish" ''
          export PYTHONPATH="${cf-src}:$PYTHONPATH"
          
          # Load secrets if they exist
          if [ -f /run/secrets/content-factory.env ]; then
            set -a; source /run/secrets/content-factory.env; set +a
          fi
          exec ${cf-python}/bin/python3 ${cf-src}/publisher.py "$@"
        '';

        maya-migrate = pkgs.writeShellScriptBin "maya-migrate" ''
          export PYTHONPATH="${cf-src}:$PYTHONPATH"
          cd ${cf-src}
          exec ${cf-python}/bin/alembic upgrade head
        '';

        # Single entry point for all commands (useful for Windmill or a single wrapper)
        maya-all = pkgs.symlinkJoin {
          name = "maya-all";
          paths = [ maya-cli maya-publish maya-migrate ];
        };

      in
      {
        packages = {
          inherit maya-cli maya-publish maya-migrate maya-all maya-package;
          default = maya-all;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            cf-python
            pkgs.alembic
            pkgs.postgresql
          ];
          shellHook = ''
            echo "LanguageBuddy Content Factory Dev Shell"
            export PYTHONPATH=$(pwd):$PYTHONPATH
            
            if [ -f .env ]; then
              set -a; source .env; set +a
              echo "Loaded .env"
            fi

            # Default to local SQLite for development if no DB is set
            if [ -z "$DATABASE_URL" ]; then
              export DATABASE_URL="sqlite:///dev.db"
              echo "Using local SQLite database: dev.db"
            fi

            # Automatically ensure the database is up to date
            echo "Checking database migrations..."
            # Use the alembic from the environment
            alembic upgrade head
          '';
        };
      }
    );
}
