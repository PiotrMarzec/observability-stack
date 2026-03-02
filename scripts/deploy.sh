#!/usr/bin/env bash
# deploy.sh — Sync config files and deploy the observability stack
# Called by the GitHub Action after files are rsync'd to the VM.
#
# Required environment variables:
#   APPS_VM_IP       — VM1 private IP (for Prometheus scrape targets)
#   GF_ADMIN_PASSWORD — Grafana admin password
set -euo pipefail

DEPLOY_DIR="/opt/observability"

echo "==> Validating environment..."
: "${APPS_VM_IP:?Error: APPS_VM_IP is not set}"
: "${GF_ADMIN_PASSWORD:?Error: GF_ADMIN_PASSWORD is not set}"

echo "==> Creating deploy directory..."
sudo mkdir -p "$DEPLOY_DIR"

echo "==> Syncing files to ${DEPLOY_DIR}..."
# The GitHub Action rsync's the repo to ~/observability-staging/
STAGING_DIR="$HOME/observability-staging"

# Copy all config files, preserving directory structure
sudo rsync -av --delete \
    --exclude='.git' \
    --exclude='.github' \
    --exclude='scripts' \
    --exclude='README.md' \
    --exclude='.gitignore' \
    "${STAGING_DIR}/" "${DEPLOY_DIR}/"

echo "==> Substituting APPS_VM_IP placeholder in prometheus.yml..."
sudo sed -i "s/__APPS_VM_IP__/${APPS_VM_IP}/g" "${DEPLOY_DIR}/prometheus.yml"

echo "==> Writing .env file..."
sudo tee "${DEPLOY_DIR}/.env" > /dev/null <<EOF
GF_ADMIN_PASSWORD=${GF_ADMIN_PASSWORD}
EOF
sudo chmod 600 "${DEPLOY_DIR}/.env"

echo "==> Pulling latest images..."
cd "$DEPLOY_DIR"
sudo docker compose pull

echo "==> Deploying stack..."
sudo docker compose up -d --remove-orphans

echo "==> Waiting for services to be healthy..."
sleep 5

# Health checks
echo "==> Checking Loki..."
if curl -sf http://localhost:3100/ready > /dev/null 2>&1; then
    echo "    ✓ Loki is ready"
else
    echo "    ✗ Loki not ready yet (may still be starting)"
fi

echo "==> Checking Prometheus..."
if curl -sf http://localhost:9090/-/ready > /dev/null 2>&1; then
    echo "    ✓ Prometheus is ready"
else
    echo "    ✗ Prometheus not ready yet (may still be starting)"
fi

echo "==> Checking Grafana..."
if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "    ✓ Grafana is ready"
else
    echo "    ✗ Grafana not ready yet (may still be starting)"
fi

echo ""
echo "==> Deploy complete!"
echo "    Grafana:    http://$(hostname -I | awk '{print $1}'):3000"
echo "    Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo "    Loki:       http://$(hostname -I | awk '{print $1}'):3100"
