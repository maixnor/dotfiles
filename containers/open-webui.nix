{
  image = "ghcr.io/open-webui/open-webui:main";

  environment = {
    "TZ" = "Europe/Amsterdam";
    "OLLAMA_API_BASE_URL" = "http://127.0.0.1:11434/api";
    "OLLAMA_BASE_URL" = "http://127.0.0.1:11434";
  };

  volumes = [
    "open-webui:/var/data/open-webui"
  ];

  ports = [
    "127.0.0.1:7080:8080" # Ensures we listen only on localhost
  ];

  extraOptions = [
    "--pull=newer" # Pull if the image on the registry is newer
    "--name=open-webui"
    "--hostname=open-webui"
    "--network=host"
    "--add-host=host.containers.internal:host-gateway"
  ];
}

