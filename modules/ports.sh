#!/usr/bin/env bash
run_ports() {
  local subs="$ASSETS_DIR/subdomains.txt" out="$NETWORK_DIR/ports.txt"
  stage_done "$out" && { log_info "Resume: port inventory already present"; return; }
  require_cmd naabu || return 0
  [[ -s "$subs" ]] || { log_warn "No scoped hosts for port scan"; return 0; }
  naabu -list "$subs" -rate "$RATE_LIMIT" -silent -o "$out" || log_warn "naabu failed"
}
