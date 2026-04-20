#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

log()  { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WAIT]${RESET} $1"; }
err()  { echo -e "${RED}[ERR]${RESET} $1" >&2; exit 1; }

PF_PIDS=()

pf_start() {
  local ns=$1 svc=$2 ports=$3
  pkill -f "port-forward.*${ports%%:*}" 2>/dev/null || true
  while true; do
    kubectl port-forward "svc/${svc}" "${ports}" -n "${ns}" --address 0.0.0.0 2>/dev/null
    sleep 2
  done &
  PF_PIDS+=($!)
}

pf_cleanup() {
    [[ ${#PF_PIDS[@]} -gt 0 ]] && kill "${PF_PIDS[@]}" 2>/dev/null || true;
}

poll_api() {
  local url=$1 max=${2:-60} interval=${3:-5} count=0
  warn "Polling ${url} ..."
  until [[ $(curl -s -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null) == "200" ]]; do
    (( count++ )); (( count > max )) && err "Timeout waiting for ${url}"
    warn "Not ready yet (${count}/${max}) ..."; sleep "${interval}"
  done
  log "API ready: ${url}"
}

print_credentials() {
  local host; host=$(hostname -I | awk '{print $1}')
  echo -e "\n${DIM}────────────────────────────────────────${RESET}"
  echo -e "  ${BOLD}${CYAN}CREDENTIALS${RESET}"
  echo -e "${DIM}────────────────────────────────────────${RESET}\n"
  echo -e "  ${BOLD}Gitea${RESET}   http://${host}:3000  |  gitadmin / Gitea_Passw0rd1337"
  echo -e "  ${BOLD}ArgoCD${RESET}  http://${host}:8081  |  admin / Passwd1337"
  echo -e "  ${BOLD}App${RESET}     http://${host}:8888"
  echo -e "\n${DIM}────────────────────────────────────────${RESET}\n"
}
