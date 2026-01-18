{ pkgs, lib, ... }:

let
  cf-python = pkgs.python3.withPackages (ps: with ps; [
    alembic
    sqlalchemy
    psycopg2
    beautifulsoup4
    httpx
    google-genai
    pillow
  ]);

  # The source of the content factory scripts
  cf-src = ../content-factory;

  # A wrapper script that sets up PYTHONPATH and calls main.py
  maya-cli = pkgs.writeShellScriptBin "maya-cli" ''
    export PYTHONPATH="${cf-src}:$PYTHONPATH"
    export MONTSERRAT_FONT="${pkgs.montserrat}/share/fonts/opentype/Montserrat-Bold.otf"
    if [ -f /run/secrets/gemini-api-key ]; then
      export GEMINI_API_KEY_FILE=/run/secrets/gemini-api-key
    fi
    exec ${cf-python}/bin/python3 ${cf-src}/main.py "$@"
  '';

  # Specialized wrappers for convenience and for use in systemd/Windmill
  maya-publish = pkgs.writeShellScriptBin "maya-publish" ''
    export PYTHONPATH="${cf-src}:$PYTHONPATH"
    if [ -f /run/secrets/gemini-api-key ]; then
      export GEMINI_API_KEY_FILE=/run/secrets/gemini-api-key
    fi
    exec ${cf-python}/bin/python3 ${cf-src}/publisher.py "$@"
  '';

  maya-migrate = pkgs.writeShellScriptBin "maya-migrate" ''
    export PYTHONPATH="${cf-src}:$PYTHONPATH"
    cd ${cf-src}
    exec ${cf-python}/bin/alembic upgrade head
  '';

in {
  environment.systemPackages = [
    maya-cli
    maya-publish
    maya-migrate
  ];

  # Expose the derivations for other modules to use if needed
  _module.args = {
    contentFactory = {
      inherit maya-cli maya-publish maya-migrate cf-python cf-src;
    };
  };
}
