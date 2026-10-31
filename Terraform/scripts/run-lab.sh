#!/usr/bin/env bash
# Local Terraform curriculum. Does not apply the AWS configuration.
set -uo pipefail

ROOT="$HOME/linux-lab/Terraform"
mkdir -p "$ROOT/logs" "$ROOT/.plugin-cache"
LOG="$ROOT/logs/lab-run.log"
export TF_PLUGIN_CACHE_DIR="$ROOT/.plugin-cache"
export TF_IN_AUTOMATION=1
exec > >(tee "$LOG") 2>&1

FAILS=0
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }

echo "===== $(date '+%Y-%m-%dT%H:%M:%S%z') ====="
terraform version
echo "----- help (first 20) -----"
terraform -help | head -n 20

echo "===== credentials (no configure) ====="
if aws sts get-caller-identity; then
  echo "sts_exit=0"
else
  echo "sts_exit=$?"
fi

echo "===== fmt ====="
terraform fmt -recursive "$ROOT"

echo "===== fundamentals ====="
cd "$ROOT/fundamentals"
terraform init -input=false
terraform validate
echo "----- plan default -----"
terraform plan -input=false -no-color
terraform apply -input=false -auto-approve -no-color
echo "----- hello.txt -----"
cat hello.txt
echo "----- output -----"
terraform output
echo "----- state list -----"
terraform state list
echo "----- state show -----"
terraform state show local_file.study
echo "----- plan -var Docker -----"
terraform plan -input=false -no-color -var='student_name=Docker'
echo "----- plan TF_VAR AWS -----"
TF_VAR_student_name="AWS" terraform plan -input=false -no-color
echo "----- plan env AWS overridden by -var Docker -----"
TF_VAR_student_name="AWS" terraform plan -input=false -no-color -var='student_name=Docker'
echo "----- output -json -----"
terraform output -json
echo "----- saved plan Linux -----"
terraform plan -input=false -no-color -var='student_name=Linux' -out=study.tfplan
terraform show -no-color study.tfplan
terraform apply -input=false -no-color study.tfplan
echo "----- hello after Linux plan -----"
cat hello.txt
rm -f study.tfplan
echo "----- graph (local_file edges) -----"
terraform graph | grep -E 'local_file|output' || true

echo "===== drift on fundamentals ====="
terraform apply -input=false -auto-approve -no-color -var='student_name=Terraform' >/dev/null
echo "before: $(cat hello.txt)"
echo "Manual modification" > hello.txt
echo "drifted: $(cat hello.txt)"
terraform plan -input=false -no-color -var='student_name=Terraform'
terraform apply -input=false -auto-approve -no-color -var='student_name=Terraform'
echo "repaired: $(cat hello.txt)"
if [ "$(cat hello.txt)" = "Hello, Terraform!" ]; then
  pass "fundamentals drift repaired"
else
  fail "fundamentals drift repaired ($(cat hello.txt))"
fi

echo "===== module ====="
cd "$ROOT/modular"
terraform init -input=false
terraform validate
terraform apply -input=false -auto-approve -no-color
terraform output

echo "===== lifecycle ====="
cd "$ROOT/lifecycle"
cp main.tf "$ROOT/logs/lifecycle-main.tf.bak"
terraform init -input=false
terraform apply -input=false -auto-approve -no-color
python3 - <<'PY'
from pathlib import Path
p = Path("main.tf")
p.write_text(p.read_text().replace('content  = "one\\n"', 'content  = "two\\n"', 1))
PY
set +e
terraform plan -input=false -detailed-exitcode -no-color
IGNORE_EXIT=$?
set -e
echo "ignore_changes_plan_exit=$IGNORE_EXIT"
cp "$ROOT/logs/lifecycle-main.tf.bak" main.tf
set +e
terraform plan -destroy -input=false -no-color
DESTROY_PLAN_EXIT=$?
set -e
echo "prevent_destroy_plan_exit=$DESTROY_PLAN_EXIT"
python3 - <<'PY'
from pathlib import Path
p = Path("main.tf")
text = p.read_text()
old = '''  lifecycle {
    prevent_destroy = true
  }
'''
if old not in text:
    raise SystemExit("prevent_destroy block missing")
p.write_text(text.replace(old, "", 1))
PY
terraform destroy -input=false -auto-approve -no-color
cp "$ROOT/logs/lifecycle-main.tf.bak" main.tf
rm -f "$ROOT/logs/lifecycle-main.tf.bak" kept.txt quiet.txt
if [ "$IGNORE_EXIT" -eq 0 ]; then
  pass "ignore_changes hid content edit"
else
  fail "ignore_changes plan exit $IGNORE_EXIT"
fi
if [ "$DESTROY_PLAN_EXIT" -ne 0 ]; then
  pass "prevent_destroy blocked destroy plan"
else
  fail "prevent_destroy allowed destroy plan"
fi

echo "===== PoC 1 ====="
cd "$ROOT/poc1-drift"
chmod +x test.sh
if ./test.sh; then
  pass "PoC1"
else
  fail "PoC1"
fi
rm -f drift.tfplan

echo "===== PoC 2 ====="
cd "$ROOT/poc2-import"
chmod +x test.sh
if ./test.sh; then
  pass "PoC2"
else
  fail "PoC2"
fi
rm -f import.tfplan

echo "===== PoC 3 static only ====="
cd "$ROOT/poc3-aws"
chmod +x test.sh
if ./test.sh; then
  pass "PoC3"
else
  fail "PoC3"
fi
echo "----- poc3 graph edges -----"
terraform graph | grep -E 'aws_vpc|aws_subnet|aws_instance|aws_internet|aws_route|aws_security' || true
if [ -f terraform.tfstate ]; then
  fail "PoC3 created a state file"
else
  pass "PoC3 has no state file"
fi

echo "===== git ====="
if git -C "$HOME/linux-lab" rev-parse --is-inside-work-tree; then
  echo "repo=yes"
else
  echo "repo=no exit=$?"
fi

echo "FAILS=$FAILS"
if [ "$FAILS" -ne 0 ]; then
  exit 1
fi
echo "ALL LAB CHECKS PASSED"
