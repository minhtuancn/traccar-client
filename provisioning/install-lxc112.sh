#!/usr/bin/env bash
set -euo pipefail
[[ $(id -u) == 0 ]] || { echo "Run as root on LXC112"; exit 1; }
[[ $(hostname) == prod-traccar ]] || { echo "Unexpected host; refusing installation"; exit 1; }
cd "$(dirname "$0")"
if ! getent passwd zalgps-prov >/dev/null; then
  useradd --system --no-create-home --shell /usr/sbin/nologin zalgps-prov
fi
install -d -m 0755 /opt/zalgps-provisioning
install -d -m 0700 /etc/zalgps-provisioning
install -d -m 0700 -o zalgps-prov -g zalgps-prov /var/lib/zalgps-provisioning
if [[ ! -e /etc/zalgps-provisioning/traccar-token ]]; then
  install -m 0600 /dev/null /etc/zalgps-provisioning/traccar-token
fi
install -m 0644 server.py /opt/zalgps-provisioning/server.py
install -m 0644 zalgps-provisioning.service /etc/systemd/system/zalgps-provisioning.service
systemctl daemon-reload
systemctl enable --now zalgps-provisioning.service
