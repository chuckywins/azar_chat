#!/usr/bin/env bash
# Pull latest azar_chat repo + install deps + (re-)wire env file + restart service.
# Run on the VPS as root.

set -euo pipefail

REPO_DIR="/opt/azar_chat"
SERVER_DIR="$REPO_DIR/server"
SERVICE_NAME="azar-chat-server"
ENV_DIR="/etc/azar-chat"
ENV_FILE="$ENV_DIR/env"
UNIT="/etc/systemd/system/${SERVICE_NAME}.service"

echo "==> 1/5  git pull"
git -C "$REPO_DIR" fetch --depth 1 origin main
git -C "$REPO_DIR" reset --hard origin/main

echo "==> 2/5  npm install"
cd "$SERVER_DIR"
npm install --omit=dev --no-audit --no-fund

echo "==> 3/5  EnvironmentFile setup"
mkdir -p "$ENV_DIR"
chmod 750 "$ENV_DIR"
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<'TEMPLATE'
# kerochat / azar_chat server env
# Required for Supabase auth + ban enforcement.
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_JWT_SECRET=
TEMPLATE
  chmod 600 "$ENV_FILE"
  echo "    Created $ENV_FILE — edit it with your values, then re-run this script."
fi

echo "==> 4/5  systemd unit refresh"
cat > "$UNIT" <<EOF
[Unit]
Description=azar_chat signaling + matchmaking server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${SERVER_DIR}
EnvironmentFile=-${ENV_FILE}
Environment=PORT=9090
Environment=HOST=127.0.0.1
ExecStart=/usr/bin/node ${SERVER_DIR}/server.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"
sleep 2

echo "==> 5/5  health check"
systemctl status "${SERVICE_NAME}" --no-pager | head -8
echo
curl -s http://127.0.0.1:9090/health | head -1
echo
echo "Done. If authMode=open in the JSON, fill in $ENV_FILE and re-run this script."
