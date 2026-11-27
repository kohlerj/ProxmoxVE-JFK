#!/usr/bin/env bash
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Author: Julien
# License: MIT
# Source: https://github.com/kohlerj/houseledger

APP="HouseLedger"
var_tags="${var_tags:-finance;household}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-16}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -x /opt/houseledger/houseledger || ! -d /opt/houseledger-src/.git ]]; then
    msg_error "No ${APP} installation found!"
    exit 1
  fi

  msg_info "Checking for HouseLedger updates"
  if ! git -C /opt/houseledger-src fetch --depth=1 origin main; then
    msg_error "Could not fetch HouseLedger source from GitHub"
    exit 1
  fi
  LATEST_COMMIT=$(git -C /opt/houseledger-src rev-parse FETCH_HEAD)
  INSTALLED_COMMIT=$(cat /opt/houseledger/.source-revision 2>/dev/null || true)
  if [[ "$LATEST_COMMIT" == "$INSTALLED_COMMIT" ]]; then
    msg_ok "HouseLedger is up to date"
    exit
  fi

  if ! git -C /opt/houseledger-src checkout --detach "$LATEST_COMMIT"; then
    msg_error "Could not check out HouseLedger ${LATEST_COMMIT}"
    exit 1
  fi

  msg_info "Building HouseLedger"
  if ! (cd /opt/houseledger-src && $STD env CGO_ENABLED=0 go build -trimpath -o /opt/houseledger/houseledger.new .); then
    rm -f /opt/houseledger/houseledger.new
    msg_error "HouseLedger build failed"
    exit 1
  fi
  msg_ok "Built HouseLedger"

  msg_info "Restarting HouseLedger"
  if ! systemctl stop houseledger || ! mv -f /opt/houseledger/houseledger.new /opt/houseledger/houseledger ||
    ! systemctl start houseledger; then
    msg_error "Could not restart HouseLedger"
    exit 1
  fi
  printf '%s\n' "$LATEST_COMMIT" >/opt/houseledger/.source-revision
  msg_ok "Updated HouseLedger"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:8080${CL}"
echo -e "${YW}HouseLedger has no login; restrict access to trusted networks.${CL}"
