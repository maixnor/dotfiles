# Content Factory - Developer Guide

This guide explains how to develop, test, and deploy the `content-factory` (Maya) within this NixOS-managed infrastructure.

## Architecture Overview

The Content Factory is a Python-based automation suite that powers "Maya," the AI face of LanguageBuddy.

- **Core Logic**: Located in `content-factory/`.
- **Packaging**: Managed as a Nix flake using `buildPythonPackage`.
- **Deployment**: Integrated into `wieselburg` via `services/content-factory.nix`.
- **Orchestration**: Self-hosted **Windmill** instance runs the scripts.
- **Database**: PostgreSQL database named `content_factory` on the host.

## Development Environment

### Local Development (Nix Shell)
To get a fully functional dev environment with all dependencies:

```bash
cd content-factory
nix develop
```

This shell provides:
- Python 3.12 with all required packages (Gemini SDK, SQLAlchemy, etc.).
- `alembic` for database migrations.
- A local SQLite database (`dev.db`) initialized automatically for testing.
- `PYTHONPATH` correctly set to the current directory.

### Configuration
The application expects environment variables for secrets. Create a `.env` file in `content-factory/` for local testing:
```bash
GEMINI_API_KEY=your_key_here
DATABASE_URL=postgresql://content_factory@localhost/content_factory
```

## Testing & Pipelines

### Manual CLI Testing
The `maya-cli` (or `python main.py`) is the primary entry point:

```bash
# Brainstorm new ideas
python main.py brainstorm --count 5

# List suggested ideas from DB
python main.py list-ideas

# Draft a specific idea (ID from list-ideas)
python main.py draft --ids 1 2
```

### Nix Build Verification
Before pushing changes, ensure the Nix package still builds:
```bash
# From project root
nix build .#content-factory
```

### Database Migrations
We use Alembic for schema changes.
```bash
# Generate a new migration
alembic revision --autogenerate -m "Add new column"

# Apply migrations locally
alembic upgrade head
```
When deployed, the `content-factory-migrate.service` runs `maya-migrate` automatically on system activation.

## Server Integration (Windmill)

### Linking to the Host
The Content Factory is "baked" into the Windmill worker environment via `services/content-factory.nix`. 
- The `maya-package` site-packages are added to the worker's `PYTHONPATH`.
- The worker runs with a Python 3.12 interpreter that has all dependencies pre-installed.

### Executing via Windmill
To bypass Windmill's internal dependency resolver (`uv`), always use **dynamic imports** for local modules:

```python
import importlib
def main(count: int = 10):
    # This imports the module from the Nix-provided PYTHONPATH
    ws = importlib.import_module("windmill_scripts")
    return ws.brainstorm(count=count)
```

## Deployment Flow
1. **Develop**: Edit files in `content-factory/`.
2. **Test**: Use `nix develop` and `python main.py`.
3. **Verify Nix**: `nix build .#content-factory`.
4. **Deploy**: `just update wieselburg`. This rebuilds the package and restarts Windmill workers.
5. **Migrate**: The systemd service handles DB updates automatically.
