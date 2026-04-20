#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

kubectl -n dev rollout status deploy/wil42-playground --timeout=120s

pf_start dev wil42-playground 8888:8888
sleep 3
poll_api "http://localhost:8888/" 12 5

log "Live at http://$(hostname -I | awk '{print $1}'):8888"
print_credentials
