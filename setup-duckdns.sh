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

# 1. Prompt for DuckDNS Token
read -rsp "Enter your DuckDNS Token: " DUCKDNS_TOKEN < /dev/tty
echo ""
if [[ -z "$DUCKDNS_TOKEN" ]]; then
    echo "Error: DuckDNS token cannot be empty."
    exit 1
fi

SUBDOMAIN="awsus11elm"
DOMAIN="${SUBDOMAIN}.duckdns.org"

# 2. Ensure Docker and Docker Compose are available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please run setup-wg.sh first or install Docker."
    exit 1
fi

# 3. Create DuckDNS Directory & Compose File
WORKDIR="${HOME}/duckdns"
echo "--> Creating compose configuration at ${WORKDIR}..."
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

cat <<EOF > docker-compose.yml
services:
  duckdns:
    image: lscr.io/linuxserver/duckdns:latest
    container_name: duckdns
    network_mode: host
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - SUBDOMAINS=${SUBDOMAIN}
      - TOKEN=${DUCKDNS_TOKEN}
      - LOG_FILE=true
    volumes:
      - ~/.duckdns/config:/config
    restart: unless-stopped
EOF

# 4. Launch Stack
echo "--> Launching DuckDNS container..."
sudo docker compose up -d

echo ""
echo "=========================================="
echo "    DuckDNS Setup Complete!               "
echo "=========================================="
echo "Domain: ${DOMAIN}"
echo "Logs:   sudo docker logs -f duckdns"
echo "=========================================="
