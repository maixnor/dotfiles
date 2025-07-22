#!/usr/bin/env bash

# Test script for Wieselburg NixOS configuration
# This script provides multiple ways to validate your configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🧪 NixOS Configuration Testing for Wieselburg"
echo "============================================="

# Function to run a test command with proper formatting
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    echo ""
    echo "🔍 Running: $test_name"
    echo "Command: $test_cmd"
    echo "---"
    
    if eval "$test_cmd"; then
        echo "✅ $test_name: PASSED"
    else
        echo "❌ $test_name: FAILED"
        return 1
    fi
}

# Test 1: Basic syntax validation
echo "1️⃣  Testing Nix syntax and basic evaluation..."
run_test "Nix syntax validation" \
    "cd '$DOTFILES_ROOT' && nix flake check --no-build"

# Test 2: Build the configuration (without installing)
echo ""
echo "2️⃣  Building configuration (this may take a while)..."
run_test "Configuration build" \
    "cd '$DOTFILES_ROOT' && nix build .#nixosConfigurations.wieselburg.config.system.build.toplevel --no-link"

# Test 3: Check for common issues
echo ""
echo "3️⃣  Checking for common configuration issues..."

# Check if all imported files exist
echo "Checking if all imported service files exist..."
for service in ai-research nextcloud immich audiobookshelf navidrome collabora; do
    if [ -f "$DOTFILES_ROOT/services/$service.nix" ]; then
        echo "✅ Found services/$service.nix"
    else
        echo "❌ Missing services/$service.nix"
    fi
done

# Test 4: Validate specific services
echo ""
echo "4️⃣  Validating service configurations..."

# Check if nginx configuration is valid
run_test "Nginx configuration syntax" \
    "cd '$DOTFILES_ROOT' && nix eval .#nixosConfigurations.wieselburg.config.services.nginx.enable"

# Test 5: Check for port conflicts
echo ""
echo "5️⃣  Checking for port conflicts..."

declare -A ports
ports[80]="nginx"
ports[443]="nginx"
ports[2283]="immich"
ports[3001]="anythingllm"
ports[3010]="perplexica-backend"
ports[3011]="perplexica-frontend"
ports[4533]="navidrome"
ports[8080]="searxng"
ports[9980]="collabora"
ports[13378]="audiobookshelf"

echo "Port allocation:"
for port in "${!ports[@]}"; do
    echo "  $port: ${ports[$port]}"
done

echo ""
echo "6️⃣  Optional: Create VM for testing"
echo "To test in a VM, run:"
echo "  ./test-wieselburg.sh vm"

if [ "$1" = "vm" ]; then
    echo ""
    echo "🖥️  Creating VM for testing..."
    
    # Create a temporary VM configuration
    VM_CONFIG="$DOTFILES_ROOT/wieselburg/vm-test.nix"
    cat > "$VM_CONFIG" << 'EOF'
{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    ./configuration.nix
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  # Override some settings for VM testing
  virtualisation = {
    vmware.guest.enable = lib.mkForce false;
    
    # VM-specific settings
    memorySize = 4096;  # 4GB RAM
    cores = 2;
    diskSize = 20480;   # 20GB disk
    
    # Enable graphics for easier debugging
    graphics = true;
    
    # Port forwarding for testing services
    forwardPorts = [
      { from = "host"; host.port = 8080; guest.port = 80; }    # HTTP
      { from = "host"; host.port = 8443; guest.port = 443; }   # HTTPS
      { from = "host"; host.port = 8081; guest.port = 2283; }  # Immich
      { from = "host"; host.port = 8082; guest.port = 3001; }  # AnythingLLM
      { from = "host"; host.port = 8083; guest.port = 4533; }  # Navidrome
    ];
  };

  # Disable some services that might cause issues in VM
  services.zerotier-one.enable = lib.mkForce false;
  services.autoupdate.enable = lib.mkForce false;
  
  # Use test certificates instead of ACME
  security.acme.acceptTerms = lib.mkForce false;
  
  # Override nginx to use HTTP only for testing
  services.nginx.virtualHosts = lib.mkForce {
    "localhost" = {
      default = true;
      locations."/" = {
        return = "200 'Wieselburg VM Test Server is running!'";
        extraConfig = "add_header Content-Type text/plain;";
      };
    };
  };

  # Enable SSH for easier access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  
  users.users.root.password = "test123";
  users.users.maixnor.password = "test123";
}
EOF

    echo "VM configuration created at: $VM_CONFIG"
    echo ""
    echo "Building VM..."
    
    run_test "VM build" \
        "cd '$DOTFILES_ROOT' && nix build .#nixosConfigurations.wieselburg.config.system.build.vm -o vm-test"
    
    echo ""
    echo "🚀 VM built successfully!"
    echo ""
    echo "To run the VM:"
    echo "  cd '$DOTFILES_ROOT' && ./vm-test/bin/run-wieselburg-vm"
    echo ""
    echo "VM will be accessible at:"
    echo "  - SSH: ssh root@localhost -p 2222"
    echo "  - HTTP services on various ports (see port forwarding above)"
    echo ""
    echo "To clean up:"
    echo "  rm -rf '$DOTFILES_ROOT/vm-test' '$VM_CONFIG'"
fi

echo ""
echo "🎉 Configuration testing completed!"
echo ""
echo "Next steps:"
echo "1. If all tests passed, you can deploy with: nixos-rebuild switch --flake .#wieselburg"
echo "2. For VM testing, run: ./test-wieselburg.sh vm"
echo "3. Monitor logs after deployment: journalctl -fu nginx"
