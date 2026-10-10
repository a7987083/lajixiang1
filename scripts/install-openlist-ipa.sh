#!/usr/bin/env bash
set -Eeuo pipefail
REPO="a7987083/lajixiang1"
TAG="openlist-ipa-v4.2.6-baseline"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
ROOT="/opt/openlist"
SERVICE="openlist"
PORT="5244"
if [[ ${EUID} -ne 0 ]]; then echo "Please run with sudo" >&2; exit 1; fi
if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then echo "This installer supports only Linux x86_64" >&2; exit 1; fi
if systemctl is-active --quiet "$SERVICE"; then echo "Existing openlist service is running; refusing to overwrite." >&2; exit 1; fi
if [[ -e "$ROOT/openlist" || -e "/etc/systemd/system/$SERVICE.service" ]]; then echo "Existing installation detected; refusing to overwrite." >&2; exit 1; fi
if ss -ltnH "( sport = :$PORT )" | grep -q .; then echo "Port $PORT already occupied." >&2; exit 1; fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fL --retry 3 --connect-timeout 15 -o "$TMP/openlist-linux-amd64" "${BASE_URL}/openlist-linux-amd64"
curl -fL --retry 3 --connect-timeout 15 -o "$TMP/SHA256SUMS" "${BASE_URL}/SHA256SUMS"
test -s "$TMP/openlist-linux-amd64"
test -s "$TMP/SHA256SUMS"
(cd "$TMP" && sha256sum -c SHA256SUMS)
install -d -m 0755 "$ROOT"
install -m 0755 "$TMP/openlist-linux-amd64" "$ROOT/openlist"
install -d -m 0700 "$ROOT/data"
cat > "/etc/systemd/system/$SERVICE.service" <<'UNIT'
[Unit]
Description=OpenList v4.2.6 Custom Baseline
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/openlist
ExecStart=/opt/openlist/openlist server --data /opt/openlist/data
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now "$SERVICE"
sleep 3
systemctl --no-pager --full status "$SERVICE" || true
echo "Installed at $ROOT (data: $ROOT/data). Expected port: $PORT"
echo "Access: http://SERVER_IP:$PORT (ensure firewall access)."
echo "Admin initial password: see OpenList first-start logs; do not share it publicly."
echo "NOTE: THIS IS OFFICIAL v4.2.6 BASELINE WITHOUT IPA ENHANCEMENTS."
