#!/usr/bin/env bash
set -euo pipefail

# 실습은 처음부터 깨끗한 State에서 시작
test ! -f terraform.tfstate || {
  echo "Use a fresh directory for this PoC"
  exit 1
}

echo 'managed-by-terraform' > existing.txt

terraform init -input=false
terraform fmt -check -recursive
terraform validate

echo "[1] Import existing file path"
terraform import \
  terraform_data.existing \
  "$PWD/existing.txt"

echo "[2] Verify no destructive changes"
terraform plan -input=false -out=import.tfplan

terraform show -json import.tfplan |
  jq -e '
    [.resource_changes[]? |
      select(.address == "terraform_data.existing") |
      .change.actions] |
    all(. == ["no-op"])
  '

terraform state list | grep -qx 'terraform_data.existing'

echo "[3] Apply module and outputs"
terraform apply -input=false import.tfplan

python3 - <<'PY'
import subprocess
content = subprocess.check_output(["terraform", "output", "-raw", "imported_content"])
imported_id = subprocess.check_output(["terraform", "output", "-raw", "imported_id"])
assert content == b"managed-by-terraform\n", repr(content)
print("content=" + content.decode())
print("id=" + imported_id.decode())
PY

echo "PASS: import and module output verified"
