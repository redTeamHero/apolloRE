#!/usr/bin/env bash
run_report() {
  local out="$RUN_DIR/report.md"
  local subs=0 alive=0 ports=0 urls=0 js=0 findings=0
  [[ -f "$ASSETS_DIR/subdomains.txt" ]] && subs=$(wc -l < "$ASSETS_DIR/subdomains.txt")
  [[ -f "$ASSETS_DIR/alive.txt" ]] && alive=$(wc -l < "$ASSETS_DIR/alive.txt")
  [[ -f "$NETWORK_DIR/ports.txt" ]] && ports=$(wc -l < "$NETWORK_DIR/ports.txt")
  [[ -f "$WEB_DIR/urls.txt" ]] && urls=$(wc -l < "$WEB_DIR/urls.txt")
  [[ -f "$WEB_DIR/javascript.txt" ]] && js=$(wc -l < "$WEB_DIR/javascript.txt")
  [[ -f "$FINDINGS_DIR/nuclei.jsonl" ]] && findings=$(wc -l < "$FINDINGS_DIR/nuclei.jsonl")
  cat > "$out" <<EOF
# ApolloRE Report: $ROOT_DOMAIN

Generated: $(date -u '+%Y-%m-%d %H:%M UTC')

## Scope
- Root domain: \`$ROOT_DOMAIN\`
- Mode: \`$MODE\`
- Rate limit: \`$RATE_LIMIT\`

## Summary
- Scoped subdomains: $subs
- Live web targets: $alive
- Open host/port entries: $ports
- Crawled URLs: $urls
- JavaScript URLs: $js
- Nuclei findings: $findings

## Result locations
- Assets: \`assets/\`
- Web inventory: \`web/\`
- Network inventory: \`network/\`
- Findings: \`findings/\`
- Screenshots: \`screenshots/\`
- Logs: \`logs/\`

> Use ApolloRE only against systems you own or have explicit authorization to assess.
EOF
}
