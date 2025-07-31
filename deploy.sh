#!/usr/bin/env bash
set -euo pipefail

# ---------------- CONFIG ----------------------
PROJECT_BASE="minecraft-server"
REGION="asia-northeast1"
ZONE="asia-northeast1-b"
INSTANCE_NAME="minecraft-vm"
FIREWALL_NAME="minecraft-server-firewall"
STATIC_IP_NAME="minecraft-server-ip"
MACHINE_TYPE="e2-standard-4"
BOOT_DISK_SIZE_GB=50
RETRY_INT=10
RETRY_MAX=300
# ----------------------------------------------

retry() {
  local cmd="$1" desc="$2"
  local start=$(date +%s)
  while true; do
    if eval "$cmd"; then
      local end=$(date +%s)
      echo -e "\e[32m$desc succeeded in $(( end - start )) seconds.\e[0m"
      break
    else
      local now=$(date +%s)
      if (( now - start >= RETRY_MAX )); then
        echo -e "\e[31m$desc failed after $RETRY_MAX seconds.\e[0m" >&2
        exit 1
      fi
      echo "$desc failed, retrying in ${RETRY_INT}s..."
      sleep "$RETRY_INT"
    fi
  done
}

echo "=== 1) Get billing account ==="
BILLING_ACCOUNT_ID=${BILLING_ACCOUNT_ID:-$(gcloud billing accounts list --filter="open=true" --format="value(name)" | head -n 1)}
if [[ -z "$BILLING_ACCOUNT_ID" ]]; then
  echo "No OPEN billing account found." >&2
  exit 1
fi
echo "Using billing account: $BILLING_ACCOUNT_ID"

echo -e "\n=== 2) Create / link project ==="
SUFFIX=$(( RANDOM % 90000 + 10000 ))
PROJECT_ID="${PROJECT_BASE}-${SUFFIX}"
gcloud projects create "$PROJECT_ID" --name="$PROJECT_BASE" --quiet
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT_ID" --quiet
gcloud config set project "$PROJECT_ID" --quiet
echo "Project ID: $PROJECT_ID"

echo -e "\n=== 3) Enable required APIs ==="
gcloud services enable compute.googleapis.com cloudapis.googleapis.com --quiet

echo -e "\n=== 4) Firewall rule (retry up to 5 min) ==="
retry \
  "gcloud compute firewall-rules create $FIREWALL_NAME \
     --direction=INGRESS --priority=1000 --network=default \
     --action=ALLOW --rules=tcp:25565 --source-ranges=0.0.0.0/0 \
     --target-tags=minecraft-server --quiet" \
  "Create firewall rule"

echo -e "\n=== 5) Reserve static IP ==="
gcloud compute addresses create "$STATIC_IP_NAME" --region="$REGION" --quiet
STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --region="$REGION" --format="value(address)")
echo "Static IP = $STATIC_IP"

echo -e "\n=== 6) Create VM (retry up to 5 min) ==="
retry \
  "gcloud compute instances create $INSTANCE_NAME \
     --zone=$ZONE --machine-type=$MACHINE_TYPE \
     --tags=minecraft-server \
     --image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts \
     --boot-disk-size=${BOOT_DISK_SIZE_GB}GB \
     --address=$STATIC_IP --quiet" \
  "Create VM"

echo -e "\n=== FINISHED ==="
EXTERNAL_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo -e "\e[32mServer deployed! Connect to $EXTERNAL_IP:25565\e[0m"

