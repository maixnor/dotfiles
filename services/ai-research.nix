{ config, pkgs, lib, ... }:

{
  # AnythingLLM - Comprehensive AI platform with research capabilities
  virtualisation.oci-containers.containers.anythingllm = {
    image = "mintplexlabs/anythingllm:latest";
    ports = [ "3001:3001" ];
    volumes = [
      "/var/lib/anythingllm/storage:/app/server/storage"
      "/var/lib/anythingllm/hotdir:/app/collector/hotdir"
      "/var/lib/anythingllm/outputs:/app/collector/outputs"
    ];
    environment = {
      # Storage and data
      STORAGE_DIR = "/app/server/storage";
      
      # Security
      JWT_SECRET = "your-jwt-secret-change-this";
      DISABLE_TELEMETRY = "true";
      
      # Server configuration
      SERVER_PORT = "3001";
      
      # Enable web browsing and research features
      AGENT_WEB_SEARCH_ENABLED = "true";
      
      # Vector database settings
      VECTOR_DB = "chroma";
      
      # Enable document processing
      ENABLE_DOCUMENT_PROCESSOR = "true";
    };
    extraOptions = [
      "--cap-add=SYS_ADMIN"
    ];
  };

  # Perplexica - AI-powered research assistant with web search
  virtualisation.oci-containers.containers.perplexica-backend = {
    image = "itzcrazykns/perplexica-backend:main";
    ports = [ "3010:3001" ];
    volumes = [
      "/var/lib/perplexica/data:/home/perplexica/data"
      "/var/lib/perplexica/config:/home/perplexica/config"
    ];
    environment = {
      # Search configuration
      SEARXNG_API_URL = "http://searxng:6666";
      
      # OpenAI configuration (you can also use local models)
      OPENAI_API_KEY = "your-openai-key-or-leave-empty-for-local";
      
      # Anthropic configuration (optional)
      ANTHROPIC_API_KEY = "your-anthropic-key-or-leave-empty";
      
      # Database
      DATABASE_URL = "file:./data/perplexica.db";
    };
    dependsOn = [ "searxng" ];
  };

  virtualisation.oci-containers.containers.perplexica-frontend = {
    image = "itzcrazykns/perplexica-frontend:main";
    ports = [ "3011:3000" ];
    environment = {
      NEXT_PUBLIC_API_URL = "http://127.0.0.1:3010/api";
      NEXT_PUBLIC_WS_URL = "ws://127.0.0.1:3010";
    };
    dependsOn = [ "perplexica-backend" ];
  };

  # Nginx configurations
  services.nginx.virtualHosts."ai.maixnor.com" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3001";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Allow large file uploads for document processing
        client_max_body_size 100M;
      '';
    };
  };

  services.nginx.virtualHosts."research.maixnor.com" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3011";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
    locations."/api/" = {
      proxyPass = "http://127.0.0.1:3010/";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  # Create necessary directories
  system.activationScripts.ai-services-setup = ''
    # AnythingLLM directories
    mkdir -p /var/lib/anythingllm/{storage,hotdir,outputs}
    
    # Perplexica directories
    mkdir -p /var/lib/perplexica/{data,config}
    
    # SearXNG directory
    mkdir -p /var/lib/searxng
    
    # Create SearXNG configuration if it doesn't exist
    if [ ! -f /var/lib/searxng/settings.yml ]; then
      cat > /var/lib/searxng/settings.yml << 'EOF'
use_default_settings: true
server:
  secret_key: "your-searxng-secret-key-change-this"
  base_url: "https://search.maixnor.com"
  image_proxy: true
search:
  safe_search: 0
  autocomplete: "google"
outgoing:
  request_timeout: 10.0
engines:
  - name: google
    disabled: false
  - name: bing
    disabled: false  
  - name: duckduckgo
    disabled: false
  - name: startpage
    disabled: false
  - name: wikipedia
    disabled: false
  - name: wikidata
    disabled: false
  - name: arxiv
    disabled: false
  - name: github
    disabled: false
  - name: stackoverflow
    disabled: false
EOF
    fi
  '';
}
