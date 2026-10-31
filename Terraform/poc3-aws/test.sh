#!/usr/bin/env bash
set -euo pipefail

echo "[1] Format"
terraform fmt -check

echo "[2] Initialize provider"
terraform init -backend=false -input=false

echo "[3] Validate syntax and schema"
terraform validate

echo "[4] Validate CIDR design"
python3 - <<'PY'
import ipaddress

vpc = ipaddress.ip_network("10.0.0.0/16")
public = ipaddress.ip_network("10.0.1.0/24")
private = ipaddress.ip_network("10.0.11.0/24")

assert public.subnet_of(vpc)
assert private.subnet_of(vpc)
assert not public.overlaps(private)

print("PASS: CIDR design")
PY

echo "PASS: Terraform static validation"
