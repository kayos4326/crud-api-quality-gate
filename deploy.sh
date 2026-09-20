#!/bin/bash
# deploy.sh
set -euo pipefail

# --- Configuration ---
VM_USER="azureuser"
# Supply the real address when deploying:
#   VM_HOST=your-name.region.cloudapp.azure.com ./deploy.sh
VM_HOST="${VM_HOST:-YOUR_AZURE_FQDN}"
KEY_PATH="$HOME/.ssh/bad-vps-01_key.pem"
TARGET_DIR="~/crud-api"

# --- Step 0: Quality gate --------------------------------------------------
# Nothing reaches the VM until SonarQube approves the code. This is the whole
# point: the gate is not advisory, it is the thing standing in front of scp.
# Emergency override:  SKIP_QUALITY_GATE=1 ./deploy.sh
if [ "${SKIP_QUALITY_GATE:-0}" = "1" ]; then
    echo "WARNING: quality gate skipped by SKIP_QUALITY_GATE=1"
else
    echo "Step 0: Running the quality gate..."
    if ! ./scripts/quality-gate.sh; then
        echo
        echo "DEPLOY ABORTED - the quality gate failed." >&2
        echo "Fix the issues above, or override with SKIP_QUALITY_GATE=1 if this is an emergency." >&2
        exit 1
    fi
    echo "Quality gate passed."
fi

echo "Step 1: Transferring backend and static UI files to Azure VM..."
# Built from what exists, so the same script works on any branch.
FILES=(app.js package.json .env dist prisma)
[ -f reporting.js ] && FILES+=(reporting.js)
scp -r -i "$KEY_PATH" "${FILES[@]}" "$VM_USER@$VM_HOST:$TARGET_DIR/"

echo "Step 2: Restarting application on the server..."
ssh -i "$KEY_PATH" "$VM_USER@$VM_HOST" << EOSSH
    cd $TARGET_DIR
    npm install
    npx prisma generate
    npx prisma migrate deploy
    sudo cp -R $TARGET_DIR/dist/* /var/www/html/
    pm2 restart crud-api
EOSSH

echo "Deployment Complete!"
