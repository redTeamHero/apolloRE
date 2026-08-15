#!/usr/bin/env bash
run_cloud() {
  local subs="$ASSETS_DIR/subdomains.txt" dns="$ASSETS_DIR/dns.txt" urls="$WEB_DIR/urls.txt" hist="$WEB_DIR/historical_urls.txt" out="$FINDINGS_DIR/cloud_candidates.txt"
  stage_done "$out" && { log_info "Resume: cloud candidates already present"; return; }
  : > "$out"
  {
    [[ -s "$subs" ]] && cat "$subs"
    [[ -s "$dns" ]] && cat "$dns"
    [[ -s "$urls" ]] && cat "$urls"
    [[ -s "$hist" ]] && cat "$hist"
  } | grep -Eaio '([A-Za-z0-9._-]+\.)?(s3[.-][A-Za-z0-9.-]*amazonaws\.com|storage\.googleapis\.com|blob\.core\.windows\.net|digitaloceanspaces\.com|r2\.cloudflarestorage\.com)' \
    | sort -u > "$out" || true
  log_info "Cloud storage candidates: $(wc -l < "$out")"
  log_info "Cloud module is passive: candidates only; no bucket/object access attempted"
}
