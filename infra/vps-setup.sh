#!/usr/bin/env bash
# azar_chat — RHEL 9 (AlmaLinux/Rocky) signaling server deploy script.
# Usage:  bash vps-setup.sh ws.example.com
# Idempotent — safe to re-run.

set -euo pipefail

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "ERROR: pass the public domain as argument, e.g.  bash vps-setup.sh ws.klslog.com"
  exit 1
fi

REPO_DIR="/opt/azar_chat"
SERVER_DIR="$REPO_DIR/server"
SERVICE_NAME="azar-chat-server"
NODE_BIN="/usr/bin/node"

echo "==> 1/8  System update + base packages"
dnf -y -q update
dnf -y -q install curl git tar

echo "==> 2/8  Node.js 20 (NodeSource)"
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d. -f1)" != "v20" ]; then
  curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
  dnf -y -q install nodejs
fi
node -v
npm -v

echo "==> 3/8  Clone / update repo at $REPO_DIR"
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" fetch --depth 1 origin main
  git -C "$REPO_DIR" reset --hard origin/main
else
  git clone --depth 1 https://github.com/chuckywins/azar_chat.git "$REPO_DIR"
fi

echo "==> 4/8  npm install"
cd "$SERVER_DIR"
npm install --omit=dev --no-audit --no-fund

echo "==> 5/8  systemd service (binds 127.0.0.1 only; Caddy exposes it)"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=azar_chat signaling + matchmaking server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${SERVER_DIR}
ExecStart=${NODE_BIN} ${SERVER_DIR}/server.js
Restart=on-failure
RestartSec=5
Environment=PORT=9090
Environment=HOST=127.0.0.1
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"
sleep 2
curl -fsS http://127.0.0.1:9090/health || { echo "Server failed to respond"; journalctl -u "${SERVICE_NAME}" --no-pager | tail -n 30; exit 1; }
echo

echo "==> 6/8  firewalld: open 80 + 443"
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
else
  echo "firewalld not active — skipping (assuming external firewall handles ingress)"
fi

echo "==> 7/8  Install Caddy (auto HTTPS via Let's Encrypt)"
if ! command -v caddy >/dev/null 2>&1; then
  dnf -y -q install 'dnf-command(copr)'
  dnf -y -q copr enable @caddy/caddy
  dnf -y -q install caddy
fi

cat > /etc/caddy/Caddyfile <<EOF
${DOMAIN} {
    reverse_proxy 127.0.0.1:9090
    encode gzip zstd
    log {
        output file /var/log/caddy/access.log {
            roll_size 10MiB
            roll_keep 5
        }
    }
}
EOF

mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy || true
systemctl enable --now caddy
systemctl reload caddy
sleep 3

echo "==> 8/8  Public health check via https://${DOMAIN}/health"
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS "https://${DOMAIN}/health" 2>/dev/null; then
    echo
    echo "✓ Signaling server live at  wss://${DOMAIN}"
    exit 0
  fi
  echo "  ...waiting for Let's Encrypt cert + DNS (attempt $i/10)"
  sleep 5
done

echo
echo "Public health check failed — check:"
echo "  - DNS A record (${DOMAIN} → this server's public IP)"
echo "  - journalctl -u caddy --no-pager | tail -n 50"
echo "  - journalctl -u ${SERVICE_NAME} --no-pager | tail -n 30"
exit 1
