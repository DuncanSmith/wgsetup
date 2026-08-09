#!/usr/bin/env bash
#
# Automated DuckDNS Docker setup script for Amazon Linux 2023 / AL2
# 

set -euo pipefail

# Redirect all output to ~/duckdns_install.txt while continuing to display on screen
LOGFILE="${HOME}/duckdns_install.txt"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=========================================="
echo "    DuckDNS Docker Setup & Deployment     "
echo "=========================================="

# 1. Prompt for DuckDNS Subdomain
read -rp "Enter your DuckDNS Subdomain (e.g., awsus11elm): " RAW_SUBDOMAIN < /dev/tty
echo ""

# Sanitize subdomain: trim whitespace/newlines & strip .duckdns.org if typed by mistake
SUBDOMAIN=$(echo "$RAW_SUBDOMAIN" | tr -d '\r\n ' | sed -E 's/\.duckdns\.org$//I')

if [[ -z "$SUBDOMAIN" ]]; then
    echo "Error: Subdomain cannot be empty."
    exit 1
fi

# 2. Prompt for DuckDNS Token
read -rsp "Enter your DuckDNS Token: " RAW_TOKEN < /dev/tty
echo ""

# Sanitize token: trim whitespace/newlines
DUCKDNS_TOKEN=$(echo "$RAW_TOKEN" | tr -d '\r\n ')

if [[ -z "$DUCKDNS_TOKEN" ]]; then
    echo "Error: DuckDNS token cannot be empty."
    exit 1
fi

DOMAIN="${SUBDOMAIN}.duckdns.org"

# 3. Ensure Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please run setup-wg.sh first or install Docker."
    exit 1
fi

# 4. Create DuckDNS Directory & Config Folder
WORKDIR="${HOME}/duckdns"
CONFIG_DIR="${WORKDIR}/config"
echo "--> Creating directories at ${WORKDIR}..."
mkdir -p "${CONFIG_DIR}"
cd "${WORKDIR}"

# 5. Create Compose File using explicit user paths
cat <<EOF > docker-compose.yml
services:
  duckdns:
    image: lscr.io/linuxserver/duckdns:latest
    container_name: duckdns
    network_mode: host
    environment:
      - PUID=$(id -u)
      - PGID=$(id -g)
      - TZ=Etc/UTC
      - SUBDOMAINS=${SUBDOMAIN}
      - TOKEN=${DUCKDNS_TOKEN}
      - LOG_FILE=true
    volumes:
      - ${CONFIG_DIR}:/config
    restart: unless-stopped
EOF

# 6. Launch Stack
echo "--> Launching DuckDNS container..."
sudo docker compose down --remove-orphans 2>/dev/null || true
sudo docker compose up -d --force-recreate

echo ""
echo "=========================================="
echo "    DuckDNS Setup Complete!               "
echo "=========================================="
echo "Domain: ${DOMAIN}"
echo "Config Path: ${CONFIG_DIR}"
echo ""
echo "Checking logs (should show OK):"
sleep 3
sudo docker logs duckdns | tail -n 10
echo "=========================================="
