#!/usr/bin/env bash

# Quick validation script for Wieselburg configuration
# Run this before building the VM to catch basic issues

set -e

DOTFILES_ROOT="$(dirname "$(readlink -f "$0")")"

echo "🔍 Quick Wieselburg Configuration Validation"
echo "==========================================="

cd "$DOTFILES_ROOT"

# Test 1: Flake check
echo "1️⃣ Checking flake syntax..."
if nix flake check --no-build 2>/dev/null; then
    echo "✅ Flake syntax is valid"
else
    echo "❌ Flake syntax errors found"
    echo "Run 'nix flake check' for details"
    exit 1
fi

# Test 2: Check if configuration builds
echo ""
echo "2️⃣ Testing configuration build..."
if nix build .#nixosConfigurations.wieselburg.config.system.build.toplevel --no-link --quiet; then
    echo "✅ Wieselburg configuration builds successfully"
else
    echo "❌ Configuration build failed"
    echo "Try running: nix build .#nixosConfigurations.wieselburg.config.system.build.toplevel"
    exit 1
fi

# Test 3: Check all service files exist
echo ""
echo "3️⃣ Checking service files..."
missing_files=()
for service in ai-research nextcloud immich audiobookshelf navidrome collabora; do
    if [ -f "services/$service.nix" ]; then
        echo "✅ services/$service.nix"
    else
        echo "❌ Missing services/$service.nix"
        missing_files+=("services/$service.nix")
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    echo "❌ Missing service files: ${missing_files[*]}"
    exit 1
fi

echo ""
echo "🎉 Production configuration validation passed!"
echo ""
echo "Next steps:"
echo "1. Test VM: ./run-vm-test.sh"
echo "2. Deploy to production: nixos-rebuild switch --flake .#wieselburg"
