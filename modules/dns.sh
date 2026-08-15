#!/usr/bin/env bash
run_dns() {
  local out="$ASSETS_DIR/dns.txt" subs="$ASSETS_DIR/subdomains.txt"
  stage_done "$out" && { log_info "Resume: DNS inventory already present"; return; }
  require_cmd dig || return 0
  [[ -s "$subs" ]] || { log_warn "No subdomains for DNS module"; return 0; }
  : > "$out"
  while IFS= read -r host; do
    in_scope_host "$host" || continue
    printf '### %s\n' "$host" >> "$out"
    for type in A AAAA CNAME MX TXT NS; do
      dig +short "$host" "$type" | sed "s/^/$type /" >> "$out" || true
    done
  done < "$subs"
}
