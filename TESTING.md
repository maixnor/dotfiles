# Testing Wieselburg Configuration

This guide helps you validate and test your Wieselburg server configuration before deploying to production.

## Quick Start

### 1. **Fast Validation** (recommended first step)
```bash
./validate-wieselburg.sh
```
This checks syntax, builds the configuration, and verifies all files exist.

### 2. **Run VM Test**
```bash
nix run .#wieselburg-vm-test
```
This starts a full VM with your services for testing.

### 3. **Manual Build Testing**
```bash
# Build configuration only (no VM)
nix build .#nixosConfigurations.wieselburg.config.system.build.toplevel

# Build VM package
nix build .#wieselburg-vm-test
```

## VM Testing Details

### What the VM includes:
- ✅ **Simplified service stack** (AnythingLLM + SearXNG for quick testing)
- ✅ **Port forwarding** to access services from your host
- ✅ **HTTP-only** setup (no SSL complexity)
- ✅ **Test credentials**: root/maixnor password is `test123`

### VM Service Access:
Once the VM is running, you can access services at:

- **Main test page**: http://localhost:8080
- **AnythingLLM**: http://localhost:8301
- **SearXNG**: http://localhost:8800
- **SSH access**: `ssh root@localhost -p 2222`

### VM Commands:
```bash
# Inside the VM, check service status:
test-services

# Check which ports are listening:
check-ports

# View logs:
journalctl -fu nginx
journalctl -fu container@anythingllm
```

## Production Deployment

After testing successfully:

```bash
# Deploy to actual Wieselburg server
nixos-rebuild switch --flake .#wieselburg --target-host root@your-server-ip
```

## Troubleshooting

### If validation fails:
1. Check syntax: `nix flake check`
2. Look for missing files in the error output
3. Verify all services/*.nix files exist

### If VM won't start:
1. Ensure you have enough RAM (VM uses 4GB)
2. Check if virtualization is enabled in BIOS
3. Try building first: `nix build .#wieselburg-vm-test`

### If services don't work in VM:
1. SSH into VM: `ssh root@localhost -p 2222`
2. Check container status: `podman ps`
3. Check logs: `journalctl -fu container@servicename`

## Resource Requirements

- **Host RAM**: 6GB+ (4GB for VM + 2GB for host)
- **Disk**: 20GB+ free space
- **CPU**: 2+ cores recommended

## Files Overview

- `wieselburg/configuration.nix` - Production configuration
- `wieselburg/vm-test.nix` - VM test configuration
- `validate-wieselburg.sh` - Quick validation script
- `test-wieselburg.sh` - Comprehensive test script
- `services/*.nix` - Individual service configurations
