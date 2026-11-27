#!/usr/bin/env bash

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing HouseLedger dependencies"
$STD apt install -y --no-install-recommends \
  ca-certificates git golang-go poppler-utils \
  tesseract-ocr tesseract-ocr-eng tesseract-ocr-fra tesseract-ocr-deu
msg_ok "Installed HouseLedger dependencies"

msg_info "Downloading HouseLedger"
if ! git clone --depth 1 --branch main https://github.com/kohlerj/houseledger.git /opt/houseledger-src; then
  msg_error "Could not download HouseLedger source"
  exit 1
fi
msg_ok "Downloaded HouseLedger"

msg_info "Building HouseLedger"
install -d -m 0755 /opt/houseledger
if ! (cd /opt/houseledger-src && $STD env CGO_ENABLED=0 go build -trimpath -o /opt/houseledger/houseledger.new .); then
  msg_error "HouseLedger build failed"
  exit 1
fi
mv /opt/houseledger/houseledger.new /opt/houseledger/houseledger
git -C /opt/houseledger-src rev-parse HEAD >/opt/houseledger/.source-revision
msg_ok "Built HouseLedger"

msg_info "Creating HouseLedger service"
if ! id houseledger >/dev/null 2>&1; then
  useradd --system --user-group --home-dir /var/lib/houseledger --shell /usr/sbin/nologin houseledger
fi
install -d -o houseledger -g houseledger -m 0700 /var/lib/houseledger
cat <<'EOF' >/etc/systemd/system/houseledger.service
[Unit]
Description=HouseLedger household expenses
After=network.target

[Service]
Type=simple
User=houseledger
Group=houseledger
Environment=HOUSELEDGER_DATA=/var/lib/houseledger
Environment=HOUSELEDGER_LISTEN=0.0.0.0:8080
EnvironmentFile=-/etc/houseledger.conf
ExecStart=/opt/houseledger/houseledger
StateDirectory=houseledger
StateDirectoryMode=0700
UMask=0077
Restart=on-failure
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now houseledger
msg_ok "Created HouseLedger service"

motd_ssh
customize
cleanup_lxc
