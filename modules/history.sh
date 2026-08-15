#!/usr/bin/env bash
run_history() {
  local out="$WEB_DIR/historical_urls.txt" raw="$WEB_DIR/historical_urls.raw.txt"
  stage_done "$out" && { log_info "Resume: historical URLs already present"; return; }
  : > "$raw"
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    if command -v gau >/dev/null 2>&1; then
      printf '%s\n' "$root" | gau --subs 2>/dev/null >> "$raw" || true
    fi
    if command -v waybackurls >/dev/null 2>&1; then
      printf '%s\n' "$root" | waybackurls 2>/dev/null >> "$raw" || true
    fi
  done < <(scope_roots | sort -u)
  [[ -s "$raw" ]] || { log_warn "No gau/waybackurls output; skipping historical URL enrichment"; rm -f "$raw"; return 0; }
  filter_scope_urls "$raw" "$out"
  rm -f "$raw"
  log_info "Historical scoped URLs: $(wc -l < "$out")"
}
