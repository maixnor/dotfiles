import os

def get_secret(env_var, default=None):
    """
    Simpler version: Secrets are now injected directly into the environment
    by systemd or the CLI wrapper.
    """
    return os.getenv(env_var, default)