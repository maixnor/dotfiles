import os

def get_secret(env_var, file_env_var=None):
    """
    Tries to get a secret from an environment variable.
    If not found and file_env_var is provided, tries to read from the path in file_env_var.
    """
    val = os.getenv(env_var)
    if val:
        return val
    
    if file_env_var:
        path = os.getenv(file_env_var)
        if path and os.path.exists(path):
            with open(path, "r") as f:
                return f.read().strip()
    
    return None
