#!/usr/bin/env bash
# bootstrap.sh — Install Docker + Compose on a fresh Ubuntu VM
# Idempotent: safe to run multiple times.
set -euo pipefail

echo "==> Checking if Docker is already installed..."
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    echo "==> Docker and Compose already installed, skipping bootstrap."
    docker --version
    docker compose version
    exit 0
fi

echo "==> Installing Docker..."

# Remove old/conflicting packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y "$pkg" 2>/dev/null || true
done

# Prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Docker repo
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group (avoids needing sudo for docker commands)
if ! groups "$USER" | grep -q docker; then
    sudo usermod -aG docker "$USER"
    echo "==> Added $USER to docker group (will take effect on next login)"
fi

echo "==> Docker installed successfully:"
docker --version
docker compose version
