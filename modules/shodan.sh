#!/usr/bin/env bash
run_shodan() {
  local out="$ASSETS_DIR/shodan.txt"
  stage_done "$out" && { log_info "Resume: Shodan enrichment already present"; return; }
  [[ -n "${SHODAN_API_KEY:-}" ]] || { log_warn "SHODAN_API_KEY not configured; skipping Shodan"; return 0; }
  require_cmd shodan || return 0
  : > "$out"
  SHODAN_API_KEY="$SHODAN_API_KEY" shodan search --fields ip_str,port,hostnames,org,product "hostname:$ROOT_DOMAIN" 2>/dev/null \
    | awk -v root="$ROOT_DOMAIN" 'index($0,root)>0 || $0 ~ /^[0-9]/ {print}' \
    | sort -u > "$out" || log_warn "Shodan search failed"
}
