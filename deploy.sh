#!/usr/bin/env bash
set -euo pipefail

# === Stylish Logging ===
timestamp() { date "+%H:%M:%S"; }

print_info()    { echo -e "\e[90m[$(timestamp)] [INFO]    $*\e[0m"; }
print_success() { echo -e "\e[32m[$(timestamp)] [SUCCESS]\e[0m $*"; }
print_error()   { echo -e "\e[31m[$(timestamp)] [ERROR]   $*\e[0m"; }
print_complete(){ echo -e "\e[38;5;214m[$(timestamp)] [COMPLETE] $*\e[0m"; }

# === CONFIG  ===
PROJECT_BASE="minecraft-server"
REGION="asia-northeast1"
ZONE="asia-northeast1-b"
INSTANCE_NAME="minecraft-vm"
FIREWALL_NAME="minecraft-server-firewall"
STATIC_IP_NAME="minecraft-server-ip"
MACHINE_TYPE="e2-standard-4"
BOOT_DISK_SIZE_GB=50
SERVER_USER="server_admin"
RETRY_INT=10
RETRY_MAX=300

USER_PROJECT_ID="${PROJECT_ID:-${1:-}}"

retry() {
  local cmd="$1" desc="$2"
  local start=$(date +%s)
  while true; do
    if eval "$cmd" > /dev/null 2>&1; then
      local end=$(date +%s)
      print_success "$desc succeeded in $(( end - start )) s."
      break
    else
      local now=$(date +%s)
      if (( now - start >= RETRY_MAX )); then
        print_error "$desc failed after ${RETRY_MAX}s"
        exit 1
      fi
      print_info "$desc failed; retrying in ${RETRY_INT}s..."
      sleep "$RETRY_INT"
    fi
  done
}

# === 1. Billing Account ===
print_info "Fetching billing account..."
BILLING_ACCOUNT_ID=${BILLING_ACCOUNT_ID:-$(gcloud billing accounts list \
  --filter="open=true" --format="value(name)" | head -n 1)}
[[ -n "$BILLING_ACCOUNT_ID" ]] || { print_error "No OPEN billing account found."; exit 1; }
print_success "Using billing account: $BILLING_ACCOUNT_ID"

# === 2. Project Setup ===
if [[ -n "$USER_PROJECT_ID" ]]; then
  PROJECT_ID="$USER_PROJECT_ID"
  print_info "Using existing project ID: $PROJECT_ID"
  gcloud config set project "$PROJECT_ID" --quiet
else
  SUFFIX=$(( RANDOM % 90000 + 10000 ))
  PROJECT_ID="${PROJECT_BASE}-${SUFFIX}"
  print_info "Creating new project: $PROJECT_ID"
  gcloud projects create "$PROJECT_ID" --name="$PROJECT_BASE" --quiet
  gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT_ID" --quiet
  gcloud config set project "$PROJECT_ID" --quiet
fi
print_success "Project set to $PROJECT_ID"

# === 3. Enable APIs ===
print_info "Enabling required APIs..."
gcloud services enable compute.googleapis.com cloudapis.googleapis.com --quiet
print_success "APIs enabled"

# === 4. Firewall Rule ===
print_info "Ensuring firewall rule exists..."
if gcloud compute firewall-rules describe "$FIREWALL_NAME" --quiet &>/dev/null; then
  print_info "Firewall rule '$FIREWALL_NAME' already exists."
else
  retry \
    "gcloud compute firewall-rules create $FIREWALL_NAME \
       --direction=INGRESS --priority=1000 --network=default \
       --action=ALLOW --rules=tcp:25565 --source-ranges=0.0.0.0/0 \
       --target-tags=minecraft-server --quiet" \
    "Create firewall rule"
fi

# === 5. Reserve Static IP ===
print_info "Reserving static IP..."
if gcloud compute addresses describe "$STATIC_IP_NAME" --region="$REGION" --quiet &>/dev/null; then
  print_info "Static IP '$STATIC_IP_NAME' already reserved."
else
  gcloud compute addresses create "$STATIC_IP_NAME" --region="$REGION" --quiet
fi
STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" \
  --region="$REGION" --format="value(address)")
print_success "Static IP reserved: $STATIC_IP"

# === 6. Create VM ===
print_info "Creating VM instance..."
if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --quiet &>/dev/null; then
  print_info "VM '$INSTANCE_NAME' already exists."
else
  retry \
    "gcloud compute instances create $INSTANCE_NAME \
       --zone=$ZONE --machine-type=$MACHINE_TYPE --tags=minecraft-server \
       --image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts \
       --boot-disk-size=${BOOT_DISK_SIZE_GB}GB \
       --address=$STATIC_IP --quiet" \
    "Create VM"
fi

EXTERNAL_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" \
              --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
print_success "VM deployed at ${EXTERNAL_IP}"

# === 7. Create server_admin ===
print_info "Creating user '${SERVER_USER}'..."
gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --command=" \
  sudo useradd -m -s /bin/bash ${SERVER_USER} 2>/dev/null || true && \
  sudo usermod -aG sudo ${SERVER_USER}" > /dev/null 2>&1
print_success "User '${SERVER_USER}' created on VM"

# === 8. Upload Setup Scripts ===
print_info "Uploading setup files..."
gcloud compute scp ./server_setup.sh ./server.properties \
  "${SERVER_USER}@${INSTANCE_NAME}:~" --zone="$ZONE" --quiet
print_success "Files uploaded"

# === 9. Execute Setup ===
print_info "Running remote setup script..."
gcloud compute ssh "${SERVER_USER}@${INSTANCE_NAME}" --zone="$ZONE" --command=" \
  chmod +x ~/server_setup.sh && \
  sudo ~/server_setup.sh ${SERVER_USER}"
print_complete "Minecraft server deployment completed at ${EXTERNAL_IP}:25565"
