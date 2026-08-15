#!/usr/bin/env bash
run_takeover() {
  local dns="$ASSETS_DIR/dns.txt" out="$FINDINGS_DIR/takeover_candidates.txt"
  stage_done "$out" && { log_info "Resume: takeover candidates already present"; return; }
  [[ -s "$dns" ]] || { log_warn "DNS inventory missing; skipping takeover candidate analysis"; return 0; }
  : > "$out"
  awk '
    /^### / {host=$2}
    /^CNAME / {
      cname=$2
      lc=tolower(cname)
      if (lc ~ /(github\.io|herokudns\.com|herokuapp\.com|azurewebsites\.net|cloudfront\.net|fastly\.net|pantheonsite\.io|readthedocs\.io|surge\.sh|zendesk\.com|shopify\.com)$/) {
        print host " -> " cname
      }
    }
  ' "$dns" | sort -u > "$out"
  log_info "Potential takeover candidates: $(wc -l < "$out")"
  log_info "Takeover module reports provider-linked CNAMEs only; it does not verify or claim resources"
}
