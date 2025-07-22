{ config, pkgs, lib, modulesPath, ... }: # Disable some services that might cause issues in VM

{
  # Disable Nextcloud for VM testing to avoid complexity
  services.nextcloud.enable = lib.mkForce false;
  services.postgresql.enable = lib.mkForce false;
  services.redis.servers.nextcloud.enable = lib.mkForce false;
  
  # Disable heavy container services for VM testing
  virtualisation.oci-containers.containers = lib.mkForce {
    # Only enable minimal services for testing
    anythingllm = {
      image = "mintplexlabs/anythingllm:latest";
      ports = [ "3001:3001" ];
      volumes = [
        "/tmp/anythingllm:/app/server/storage"
      ];
      environment = {
        STORAGE_DIR = "/app/server/storage";
        JWT_SECRET = "test-jwt-secret";
        DISABLE_TELEMETRY = "true";
        SERVER_PORT = "3001";
      };
    };
    
    searxng = {
      image = "searxng/searxng:latest";
      ports = [ "8080:8080" ];
      volumes = [
        "/tmp/searxng:/etc/searxng"
      ];
      environment = {
        SEARXNG_BASE_URL = "http://search.test";
        SEARXNG_SECRET = "test-searxng-secret";
      };
    };
  };
  
  # Override some settings for VM testing
  virtualisation = {
    vmware.guest.enable = lib.mkForce false;
    
    # VM-specific settings
    memorySize = 4096;  # 4GB RAM
    cores = 4;
    diskSize = 20480;   # 20GB disk
    
    # Enable graphics for easier debugging
    graphics = true;
    
    # Port forwarding for testing services
    forwardPorts = [
      { from = "host"; host.port = 8080; guest.port = 80; }    # HTTP
      { from = "host"; host.port = 8443; guest.port = 443; }   # HTTPS
      { from = "host"; host.port = 8281; guest.port = 2283; }  # Immich
      { from = "host"; host.port = 8301; guest.port = 3001; }  # AnythingLLM
      { from = "host"; host.port = 8310; guest.port = 3010; }  # Perplexica backend
      { from = "host"; host.port = 8311; guest.port = 3011; }  # Perplexica frontend
      { from = "host"; host.port = 8453; guest.port = 4533; }  # Navidrome
      { from = "host"; host.port = 8800; guest.port = 8080; }  # SearXNG
      { from = "host"; host.port = 8998; guest.port = 9980; }  # Collabora
      { from = "host"; host.port = 8378; guest.port = 13378; } # Audiobookshelf
    ];
  };

  # Disable some services that might cause issues in VM
  services.zerotierone.enable = lib.mkForce false;
  services.autoupdate.enable = lib.mkForce false;
  
  # Use dummy certificates instead of ACME for testing
  security.acme.acceptTerms = lib.mkForce false;
  
  # Override nginx virtual hosts for HTTP-only testing
  services.nginx.virtualHosts = lib.mkForce {
    "localhost" = {
      default = true;
      listen = [
        { addr = "0.0.0.0"; port = 80; }
      ];
      locations."/" = {
        return = "200 'Wieselburg VM Test Server is running!\n\nAvailable test services:\n- AnythingLLM: http://localhost:8301\n- Perplexica: http://localhost:8311\n- SearXNG: http://localhost:8800\n- Immich: http://localhost:8281\n- Navidrome: http://localhost:8453\n- Audiobookshelf: http://localhost:8378\n- Collabora: http://localhost:8998'";
        extraConfig = "add_header Content-Type text/plain;";
      };
    };
    
    # Test endpoints for each service (HTTP only)
    "ai.test" = {
      listen = [{ addr = "0.0.0.0"; port = 80; }];
      serverName = "ai.test";
      locations."/" = {
        proxyPass = "http://127.0.0.1:3001";
        proxyWebsockets = true;
      };
    };
    
    "research.test" = {
      listen = [{ addr = "0.0.0.0"; port = 80; }];
      serverName = "research.test";
      locations."/" = {
        proxyPass = "http://127.0.0.1:3011";
        proxyWebsockets = true;
      };
      locations."/api/" = {
        proxyPass = "http://127.0.0.1:3010/";
        proxyWebsockets = true;
      };
    };
    
    "search.test" = {
      listen = [{ addr = "0.0.0.0"; port = 80; }];
      serverName = "search.test";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
      };
    };
  };

  # Enable SSH for easier access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  
  # Set simple passwords for testing
  users.users.root.password = "test";
  users.users.maixnor.password = "test";

  # Create test directories
  system.activationScripts.vm-test-setup = ''
    mkdir -p /tmp/{anythingllm,searxng}
    
    # Create minimal SearXNG config for testing
    cat > /tmp/searxng/settings.yml << 'EOF'
use_default_settings: true
server:
  secret_key: "test-searxng-secret"
  base_url: "http://search.test"
search:
  safe_search: 0
engines:
  - name: duckduckgo
    disabled: false
EOF
  '';

  # Add helpful aliases
  environment.shellAliases = {
    test-services = "systemctl status nginx anythingllm searxng";
    check-ports = "ss -tulpn | grep -E ':(80|3001|8080)'";
  };
}
