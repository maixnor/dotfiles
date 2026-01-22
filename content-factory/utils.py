import os

def get_secret(env_var, default=None):
    """
    Retrieves a secret from environment variables, falling back to 
    the standard NixOS secret path if not found.
    """
    val = os.getenv(env_var)
    if val:
        return val

    # Fallback for CLI usage: try to read from the age-encrypted secret path
    # Check both common NixOS secret paths
    secret_paths = ["/run/secrets/content-factory.env", "/run/agenix/content-factory.env"]
    for secret_path in secret_paths:
        if os.path.exists(secret_path):
            try:
                with open(secret_path, "r") as f:
                    for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" in line:
                        k, v = line.split("=", 1)
                        key = k.strip()
                        if key.startswith("export "):
                            key = key[7:].strip()
                        if key == env_var:
                            # Strip quotes if present
                            return v.strip().strip('"').strip("'")
        except Exception:
            pass # Permissions or other read errors
            
    return default