#!/usr/bin/env bash
#
# Automated wg-easy setup script for Amazon Linux 2023 / AL2
# 

set -euo pipefail

echo "=========================================="
echo "    wg-easy EC2 Setup & Deployment       "
echo "=========================================="

# 1. Prompt for Web UI Password (forcing input from /dev/tty for curl | bash compatibility)
read -rsp "Enter a password for the wg-easy Web UI: " UI_PASSWORD < /dev/tty
echo ""
if [[ -z "$UI_PASSWORD" ]]; then
    echo "Error: Password cannot be empty."
    exit 1
fi

# 2. Update System & Install Docker
echo "--> Updating system packages..."
sudo dnf update -y || sudo yum update -y

echo "--> Installing Docker and wireguard-tools..."
sudo dnf install -y docker wireguard-tools || sudo yum install -y docker wireguard-tools

# 3. Install Docker Compose Plugin
echo "--> Installing Docker Compose CLI plugin..."
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -sSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# 4. Enable & Start Docker Service
echo "--> Enabling and starting Docker service..."
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

# 5. Enable IP Forwarding & Proxy ARP
echo "--> Configuring kernel network parameters..."
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-wireguard.conf > /dev/null
echo "net.ipv4.conf.all.proxy_arp = 1" | sudo tee -a /etc/sysctl.d/99-wireguard.conf > /dev/null
sudo sysctl --system > /dev/null

# 6. Fetch Public IP Address
echo "--> Detecting public IP address..."
PUBLIC_IP=$(curl -s https://checkip.amazonaws.com || curl -s ifconfig.me)
if [[ -z "$PUBLIC_IP" ]]; then
    echo "Error: Could not automatically determine public IP."
    exit 1
fi
echo "Detected Public IP: ${PUBLIC_IP}"

# 7. Generate & Parse Password Hash via wg-easy
echo "--> Generating password hash..."
RAW_HASH_OUTPUT=$(sudo docker run --rm ghcr.io/wg-easy/wg-easy wgpw "${UI_PASSWORD}")

# Extract only the bcrypt hash string (stripping PASSWORD_HASH= and single quotes)
PASSWORD_HASH=$(echo "$RAW_HASH_OUTPUT" | grep -oE '\$2[ayb]\$[^'\'']+' | tr -d '\r\n')

# Verify hash generation output
if [[ ! "$PASSWORD_HASH" =~ ^\$2[ayb]\$ ]]; then
    echo "Error: Failed to generate a valid bcrypt hash."
    echo "Output received: $RAW_HASH_OUTPUT"
    exit 1
fi

# 8. Create wg-easy Directory & Compose File
WORKDIR="${HOME}/wg-easy"
echo "--> Creating compose configuration at ${WORKDIR}..."
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

# Escape $ as $$ so Docker Compose doesn't try to interpolate bcrypt variables
COMPOSE_PASSWORD_HASH=$(echo "$PASSWORD_HASH" | sed 's/\$/\$\$/g')

cat <<EOF > docker-compose.yml
services:
  wg-easy:
    environment:
      - WG_HOST=${PUBLIC_IP}
      - PASSWORD_HASH=${COMPOSE_PASSWORD_HASH}
      - WG_DEFAULT_DNS=1.1.1.1
    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
    volumes:
      - ~/.wg-easy:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
EOF

# 9. Launch Stack
echo "--> Launching wg-easy container..."
sudo docker compose up -d

echo ""
echo "=========================================="
echo "    Setup Complete!                       "
echo "=========================================="
echo "Web UI URL:  http://${PUBLIC_IP}:51821"
echo ""
echo "REMINDER: In the AWS EC2 Console:"
echo " 1. Security Group: Allow UDP 51820 and TCP 51821."
echo " 2. Instance Settings: Actions -> Networking -> Disable 'Source/destination check'."
echo "=========================================="
