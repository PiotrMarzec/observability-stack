# Observability Stack (VM2)

Loki + Prometheus + Grafana deployed via GitHub Actions over SSH.

## Architecture

```
App VMs                                 Observability VM (This repo)
┌────────────────────────┐              ┌─────────────────────────┐
│  Caddy + Apps          │              │  Loki (log storage)     │
│  Fluent Bit (shipper)  │──── VPC ───→ │  Prometheus (metrics)   │
│  node_exporter         │← scrape ────│  Grafana (dashboards)   │
└────────────────────────┘              └─────────────────────────┘
```

## Initial Setup

### 1. Prepare the VM

The GitHub Action will bootstrap Docker on first deploy, but you need SSH access:

1. Create a VM (Ubuntu 22.04+ recommended)
2. Generate an SSH key pair (or use an existing one):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/observability-deploy -C "github-actions"
   ```
3. Add the **public key** to the VM's `~/.ssh/authorized_keys`
4. Note the VM's **public IP** and **SSH user** (e.g., `root` or `ubuntu`)

### 2. Configure GitHub Secrets

In your repo → Settings → Secrets and variables → Actions, add:

| Secret | Value |
|--------|-------|
| `VM_HOST` | VM2 public IP or hostname |
| `VM_USER` | SSH user (e.g., `ubuntu`) |
| `VM_SSH_KEY` | Contents of the **private** key file |
| `APPS_VM_PRIVATE_IP` | VM1 private/VPC IP (for Prometheus scraping) |
| `GF_ADMIN_PASSWORD` | Grafana admin password |

### 3. Deploy

Push to `main` — the GitHub Action will:

1. SSH into the VM
2. Install Docker + Compose (first run only)
3. Sync config files
4. Run `docker compose up -d`

You can also trigger manually from the Actions tab.

### 4. Access Grafana

Open `http://<VM2_PUBLIC_IP>:3000` and log in with `admin` / your `GF_ADMIN_PASSWORD`.

Both Loki and Prometheus are pre-configured as datasources.

## Files

```
├── docker-compose.yml          # Loki, Prometheus, Grafana
├── loki-config.yaml            # Log storage & retention (14 days)
├── prometheus.yml              # Metrics scrape targets (uses APPS_VM_IP placeholder)
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── datasources.yaml  # Auto-configures Loki + Prometheus in Grafana
├── scripts/
│   ├── bootstrap.sh            # One-time Docker install on fresh VM
│   └── deploy.sh               # Sync files + docker compose up
└── .github/
    └── workflows/
        └── deploy.yml          # GitHub Actions workflow
```

## Customization

- **Retention**: Edit `loki-config.yaml` → `retention_period` (default: 14 days)
- **Scrape targets**: Edit `prometheus.yml` to add your app metrics endpoints
- **Grafana dashboards**: Import community dashboards (Node Exporter Full: ID `1860`)

## Firewall Rules

VM2 should accept:
- **3100/tcp** from VM1 private IP (Loki ingestion)
- **3000/tcp** from your IP (Grafana UI) — or put behind a reverse proxy
- **9090/tcp** optional (Prometheus UI)

VM1 should accept from VM2 private IP:
- **9100/tcp** (node_exporter scraping)
- Any app metrics ports
