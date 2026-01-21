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
        python = pkgs.python312;
        pythonPackages = pkgs.python312Packages;

        cf-python = python.withPackages (ps: with ps; [
          alembic
          sqlalchemy
          psycopg2
          beautifulsoup4
          httpx
          google-genai
          pillow
        ]);

        maya-package = pythonPackages.buildPythonPackage {
          pname = "maya-content-factory";
          version = "0.1.0";
          src = ./.;
          pyproject = true;

          nativeBuildInputs = [
            pythonPackages.setuptools
            pythonPackages.wheel
            pkgs.makeWrapper
          ];

          propagatedBuildInputs = with pythonPackages; [
            alembic
            sqlalchemy
            psycopg2
            beautifulsoup4
            httpx
            google-genai
            pillow
          ];

          doCheck = false; # Skip tests during build

          # We still want the CLI wrappers
          postInstall = ''
            # Copy config files to the package directory in the nix store
            # This allows the wrappers to find them relative to their location
            cp alembic.ini $out/${python.sitePackages}/
            
            # Helper to source secrets if they exist
            # Note: we use a string that will be evaluated at runtime on the target system
            SECRET_LOADER='if [ -f /run/secrets/content-factory.env ]; then set -a; source /run/secrets/content-factory.env; set +a; fi'

            # Wrap the generated script to include the font path and secret loader
            if [ -e $out/bin/maya-cli ]; then
              wrapProgram $out/bin/maya-cli \
                --run "$SECRET_LOADER" \
                --set MONTSERRAT_FONT "${pkgs.montserrat}/share/fonts/otf/Montserrat-Bold.otf"
            fi

            if [ -e $out/bin/maya-publish ]; then
              wrapProgram $out/bin/maya-publish \
                --run "$SECRET_LOADER"
            fi

            # Create a dedicated migrate command that works from the site-packages dir
            makeWrapper ${pythonPackages.alembic}/bin/alembic $out/bin/maya-migrate \
              --run "$SECRET_LOADER" \
              --add-flags "upgrade head" \
              --run "cd $out/${python.sitePackages}"
          '';
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
