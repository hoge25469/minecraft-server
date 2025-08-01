#!/usr/bin/env bash
set -euo pipefail

# === Stylized Logging ===
timestamp() { date "+%H:%M:%S"; }

print_info() {
  echo -e "\e[90m[$(timestamp)] [INFO]    $*\e[0m"
}

print_success() {
  echo -e "\e[32m[$(timestamp)] [SUCCESS]\e[0m \e[0m$*"
}

print_warn() {
  echo -e "\e[33m[$(timestamp)] [WARN]    $*\e[0m"
}

print_error() {
  echo -e "\e[31m[$(timestamp)] [ERROR]   $*\e[0m"
}

print_complete() {
  echo -e "\e[38;5;214m[$(timestamp)] [COMPLETE] $*\e[0m"
}

# === Argument Check ===
[[ $# -eq 1 ]] || { print_error "Usage: $0 <SERVER_USER>"; exit 1; }
SERVER_USER="$1"
HOME_DIR="$(getent passwd "${SERVER_USER}" | cut -d: -f6)"
BASE_DIR="${HOME_DIR}/minecraft-server"
WORLD_DIR="${BASE_DIR}/data/world"

# === 1. Install Docker & Compose ===
print_info "Installing Docker and dependencies..."
apt-get update -y > /dev/null 2>&1
apt-get install -y docker.io unzip wget curl > /dev/null 2>&1
systemctl enable --now docker > /dev/null 2>&1
print_success "Docker installed"

print_info "Installing docker-compose..."
curl -fsSL "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose > /dev/null 2>&1
chmod +x /usr/local/bin/docker-compose
print_success "docker-compose installed"

# === 2. Directory Setup ===
print_info "Creating world directory: ${WORLD_DIR}"
mkdir -p "${WORLD_DIR}"
chown -R "${SERVER_USER}:${SERVER_USER}" "${HOME_DIR}"
print_success "Directory structure ready"

# === 3. Place Config File ===
print_info "Placing uploaded server.properties..."
mv "${HOME_DIR}/server.properties" "${BASE_DIR}/data/server.properties" > /dev/null 2>&1
print_success "server.properties placed"

# === 4. Download & Extract World ===
print_info "Downloading TUSB world archive..."
wget \
  --header="User-Agent: Mozilla/5.0" \
  --header="Referer: https://skyblock.jp/" \
  "https://cloud.skyblock.jp/s/NFGPMtNPoY3XHoX/download" \
  -O "${WORLD_DIR}/TUSB.zip" > /dev/null 2>&1
print_success "TUSB.zip downloaded"

print_info "Extracting TUSB.zip..."
unzip -o -q "${WORLD_DIR}/TUSB.zip" -d "${WORLD_DIR}"
rm "${WORLD_DIR}/TUSB.zip"
print_success "World extracted"

# === 5. Generate docker-compose.yml ===
print_info "Generating docker-compose.yml..."
cat <<EOF > "${BASE_DIR}/docker-compose.yml"
version: '3.8'
services:
  mc:
    image: itzg/minecraft-server:java8
    container_name: mc-server
    ports:
      - "25565:25565"
      - "25575:25575"
    environment:
      EULA: "TRUE"
      VERSION: "1.10.2"
      ENABLE_RCON: "true"
      RCON_PASSWORD: "MyS3cret!"
      RCON_PORT: "25575"
    volumes:
      - ./data:/data
    restart: unless-stopped
EOF
print_success "docker-compose.yml created"

# === 6. Add to docker group ===
print_info "Adding ${SERVER_USER} to docker group..."
usermod -aG docker "${SERVER_USER}"
print_success "User added to docker group"

# === 7. Start Server Container ===
print_info "Starting Minecraft server as ${SERVER_USER}..."
sudo -u "${SERVER_USER}" bash -c "cd '${BASE_DIR}' && docker-compose up -d" > /dev/null 2>&1
print_success "Docker container started"

# === 8. Report Success ===
EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" || true)

print_complete "Minecraft 1.10.2 server is running at ${EXTERNAL_IP:-<unknown>}:25565"
