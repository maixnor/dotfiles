#!/usr/bin/env bash
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./headscale-key.sh <user> <tag>"
  echo "Example: ./headscale-key.sh internal tag:elastic-spoke"
  echo ""
  echo "Important Users (Namespaces) for MagicDNS:"
  echo "  internal -> yields hostname.internal.probat.io"
  echo "  external -> yields hostname.external.probat.io"
  echo ""
  echo "Available tags:"
  echo "  tag:bierland"
  echo "  tag:probatio-internal"
  echo "  tag:elastic-hub"
  echo "  tag:elastic-spoke"
  echo "  tag:soc-external"
  echo "  tag:deploy"
  exit 1
fi

USER=$1
TAG=$2
SERVER="wieselburg.maixnor.com"
LOGIN_SERVER="https://headscale.maixnor.com"

echo "Ensuring user '$USER' exists..."
ssh maixnor@$SERVER -t "sudo headscale users create $USER || true"

echo "Generating pre-auth key for user '$USER' with tag '$TAG' on $SERVER..."
KEY=$(ssh maixnor@$SERVER "sudo headscale --user $USER preauthkeys create --reusable --expiration 24h --tags $TAG")

echo "===================================================================="
echo "Pre-Auth Key generated:"
echo "$KEY"
echo "===================================================================="
echo "To join the network on a client machine, run:"
echo "sudo tailscale up --login-server $LOGIN_SERVER --authkey $KEY"
