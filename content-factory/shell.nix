{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    (python3.withPackages (ps: with ps; [
      alembic
      sqlalchemy
      psycopg2
      beautifulsoup4
      httpx
      google-genai
      pillow
    ]))
  ];

  shellHook = ''
    echo "LanguageBuddy Content Factory Dev Shell"
    export PYTHONPATH=$PYTHONPATH:$(pwd)
    
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
    alembic upgrade head
  '';
}
