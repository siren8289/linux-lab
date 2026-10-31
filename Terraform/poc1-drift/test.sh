#!/usr/bin/env bash
set -euo pipefail

terraform fmt -check
terraform init -input=false
terraform validate

echo "[1] Apply desired state"
terraform apply -input=false -auto-approve

grep -qx 'environment=dev' config.txt

echo "[2] Inject drift"
echo 'environment=production' > config.txt

echo "[3] Detect drift"
terraform plan -input=false -out=drift.tfplan

# 계획에 생성 작업이 있는지 확인
terraform show -json drift.tfplan |
  jq -e '
    [.resource_changes[] |
      select(.address == "local_file.config") |
      .change.actions[]] | index("create") != null
  '

echo "[4] Restore desired state"
terraform apply -input=false drift.tfplan

grep -qx 'environment=dev' config.txt
echo "PASS: drift detected and repaired"
