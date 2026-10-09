#!/bin/bash
# USMS data tier bootstrap. Runs ONCE, as root, at first boot, via cloud-init.
# Idempotent: if a previous run completed, it exits early and changes nothing.
MARKER=/var/log/usms-db-bootstrap.done

if [ -f "$MARKER" ]; then
  echo "USMS db bootstrap already completed: $(cat "$MARKER") - nothing to do"
  exit 0
fi

set -euxo pipefail
exec > /var/log/usms-db-bootstrap.log 2>&1

dnf -y install postgresql15-server
postgresql-setup --initdb
systemctl enable --now postgresql

# Create the database only if it does not already exist.
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='usms'" | grep -q 1 \
  || sudo -u postgres createdb usms

# Ask the instance who it is, using IMDSv2.
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/instance-id")

# Written last, so the marker only exists if every step above succeeded.
echo "$INSTANCE_ID $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$MARKER"
