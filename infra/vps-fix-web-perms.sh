#!/usr/bin/env bash
# Fix ownership + perms after rsync drops Flutter web build into a DA webroot.
# Usage: bash vps-fix-web-perms.sh /home/USER/domains/chat.asicservices.com/public_html
set -euo pipefail

DEST="${1:?usage: $0 <webroot-path>}"

if [ ! -d "$DEST" ]; then
  echo "ERR: $DEST does not exist" >&2
  exit 1
fi

# DA convention: the directory's own owner is who should own the files.
OWNER="$(stat -c '%U' "$DEST")"
GROUP="$(stat -c '%G' "$DEST")"

echo "==> chown $OWNER:$GROUP $DEST"
chown -R "$OWNER:$GROUP" "$DEST"

echo "==> chmod 755 dirs / 644 files"
find "$DEST" -type d -exec chmod 755 {} +
find "$DEST" -type f -exec chmod 644 {} +

echo "==> done. files in webroot:"
ls -la "$DEST" | head -10
