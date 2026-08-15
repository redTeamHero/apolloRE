#!/usr/bin/env bash
run_history() {
  local out="$WEB_DIR/historical_urls.txt" raw="$WEB_DIR/historical_urls.raw.txt"
  stage_done "$out" && { log_info "Resume: historical URLs already present"; return; }
  : > "$raw"
  if command -v gau >/dev/null 2>&1; then
    printf '%s\n' "$ROOT_DOMAIN" | gau --subs 2>/dev/null >> "$raw" || true
  fi
  if command -v waybackurls >/dev/null 2>&1; then
    printf '%s\n' "$ROOT_DOMAIN" | waybackurls 2>/dev/null >> "$raw" || true
  fi
  [[ -s "$raw" ]] || { log_warn "No gau/waybackurls output; skipping historical URL enrichment"; rm -f "$raw"; return 0; }
  awk -v root="$ROOT_DOMAIN" '
    {u=$0; h=u; sub(/^https?:\/\//,"",h); sub(/\/.*/,"",h); sub(/:.*/,"",h); if (h==root || h ~ ("\\." root "$")) print u}
  ' "$raw" | sort -u > "$out"
  rm -f "$raw"
  log_info "Historical scoped URLs: $(wc -l < "$out")"
}
