#!/bin/bash
# deploy.sh

# --- Configuration ---
VM_USER="azureuser"
VM_HOST="chaotic-hell.eastasia.cloudapp.azure.com"
KEY_PATH="$HOME/.ssh/bad-vps-01_key.pem"
TARGET_DIR="~/crud-api"

echo "Step 1: Transferring backend and static UI files to Azure VM..."
scp -r -i $KEY_PATH app.js package.json .env dist prisma $VM_USER@$VM_HOST:$TARGET_DIR/

echo "Step 2: Restarting application on the server..."
ssh -i $KEY_PATH $VM_USER@$VM_HOST << EOF
    cd $TARGET_DIR
    npm install
    npx prisma generate
    npx prisma migrate deploy
    sudo cp -R $TARGET_DIR/dist/* /var/www/html/
    pm2 restart crud-api
EOF

echo "Deployment Complete!"
