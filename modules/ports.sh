#!/usr/bin/env bash
run_ports() {
  local subs="$ASSETS_DIR/subdomains.txt" targets="$NETWORK_DIR/port_targets.txt" out="$NETWORK_DIR/ports.txt"
  stage_done "$out" && { log_info "Resume: port inventory already present"; return; }
  require_cmd naabu || return 0
  : > "$targets"
  [[ -s "$subs" ]] && cat "$subs" >> "$targets"
  scope_ip_targets >> "$targets"
  sort -u -o "$targets" "$targets"
  [[ -s "$targets" ]] || { log_warn "No scoped hosts/IPs/CIDRs for port scan"; return 0; }
  naabu -list "$targets" -rate "$RATE_LIMIT" -silent -o "$out" || log_warn "naabu failed"
}
