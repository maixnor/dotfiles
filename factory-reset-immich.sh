#!/usr/bin/env bash

# Factory reset Immich - removes ALL data and starts fresh
# Usage: ./factory-reset-immich.sh

echo "⚠️  WARNING: This will COMPLETELY DESTROY all Immich data!"
echo "   - All photos and videos"
echo "   - All user accounts"
echo "   - All settings and configurations"
echo "   - Database content"
echo "   - Redis cache"
echo ""

echo "🛑 Stopping Immich services..."
systemctl stop immich-server immich-machine-learning || true
systemctl stop redis-immich || true

echo "🗑️  Removing all Immich data directories..."
rm -rf /var/lib/immich
rm -rf /var/cache/immich

echo "🗄️  Dropping and recreating PostgreSQL database..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS immich;"
sudo -u postgres psql -c "DROP USER IF EXISTS immich;"

echo "🔄 Running NixOS rebuild to recreate everything..."
nixos-rebuild switch

echo "⏳ Waiting for services to start..."
sleep 5

echo "✅ Factory reset complete!"
echo ""
echo "🚀 You can now access Immich at: https://photos.maixnor.com"
echo "   The initial setup wizard should appear."
echo "   Create a new admin account through the web interface."
