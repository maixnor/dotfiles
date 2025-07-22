#!/usr/bin/env bash

# Simple VM test script to avoid flake complexities
set -e

DOTFILES_ROOT="$(dirname "$(readlink -f "$0")")"
cd "$DOTFILES_ROOT"

echo "🧪 Building Wieselburg VM Test Configuration"
echo "============================================"

# First, let's validate the production config
echo "1️⃣ Validating production configuration..."
if nix build .#nixosConfigurations.wieselburg.config.system.build.toplevel --no-link --quiet; then
    echo "✅ Production configuration builds successfully"
else
    echo "❌ Production configuration failed to build"
    exit 1
fi

# Build the VM directly
echo ""
echo "2️⃣ Building VM configuration..."
if nix build .#nixosConfigurations.wieselburg-vm-test.config.system.build.vm --no-link --quiet; then
    echo "✅ VM configuration builds successfully"
else
    echo "❌ VM configuration failed to build"
    echo "This might be due to the VM module conflicts. Let's try a simpler approach..."
    exit 1
fi

# Run the VM
echo ""
echo "3️⃣ Starting VM..."
echo "Building VM..."
nix build .#nixosConfigurations.wieselburg-vm-test.config.system.build.vm -o vm-result

echo ""
echo "🚀 VM built successfully!"
echo "Starting VM (this may take a moment)..."
echo ""
echo "Services will be available at:"
echo "  - Main page: http://localhost:8080"
echo "  - AnythingLLM: http://localhost:8301"
echo "  - SearXNG: http://localhost:8800"
echo "  - SSH: ssh root@localhost -p 2222 (password: test)"
echo ""
echo "Press Ctrl+C to stop the VM"
echo ""

./vm-result/bin/run-wieselburg-vm-test-vm
