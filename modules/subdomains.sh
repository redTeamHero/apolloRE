#!/usr/bin/env bash
run_subdomains() {
  local raw="$ASSETS_DIR/subdomains.raw.txt" out="$ASSETS_DIR/subdomains.txt"
  stage_done "$out" && { log_info "Resume: subdomains already present"; return; }
  require_cmd subfinder || return 0
  subfinder -d "$ROOT_DOMAIN" -silent -o "$raw" || { log_warn "subfinder failed"; return 0; }
  printf '%s\n' "$ROOT_DOMAIN" >> "$raw"
  append_exact_scope_hosts "$raw"
  filter_scope_hosts "$raw" "$out"
  rm -f "$raw"
  log_info "Scoped hosts: $(wc -l < "$out")"
}
