#!/usr/bin/env bash
set -euo pipefail

# === 1. Install docker and docker-compose ===
apt-get update -y
apt-get install -y docker.io unzip wget curl
systemctl start docker
systemctl enable docker

# === Install docker-compose binary ===
curl -L "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# === 2. Setup project directory ===
mkdir -p /root/minecraft-server/data/world
cd /root/minecraft-server

# === 3. Move uploaded files ===
mv ~/server.properties ./data/server.properties
mv ~/TUSB.zip ./data/world/TUSB.zip

# === 4. Extract world ===
cd ./data/world
unzip -q TUSB.zip
rm TUSB.zip

cd /root/minecraft-server

# === 5. Generate docker-compose.yml ===
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  mc:
    image: itzg/minecraft-server:java8
    container_name: mc-server
    ports:
      - "25565:25565"
    environment:
      EULA: "TRUE"
      VERSION: "1.10.2"
    volumes:
      - ./data:/data
    restart: unless-stopped
EOF

# === 6. Run Minecraft Server ===
docker-compose up -d

echo "✔️ Minecraft 1.10.2 server is running with your world and command blocks enabled!"

