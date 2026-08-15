#!/usr/bin/env bash
run_subdomains() {
  local raw="$ASSETS_DIR/subdomains.raw.txt" out="$ASSETS_DIR/subdomains.txt"
  stage_done "$out" && { log_info "Resume: subdomains already present"; return; }
  require_cmd subfinder || return 0
  : > "$raw"
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    subfinder -d "$root" -silent 2>/dev/null >> "$raw" || log_warn "subfinder failed for $root"
  done < <(scope_roots | sort -u)
  append_exact_scope_hosts "$raw"
  filter_scope_hosts "$raw" "$out"
  rm -f "$raw"
  log_info "Scoped hosts: $(wc -l < "$out")"
}
