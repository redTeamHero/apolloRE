#!/usr/bin/env bash
run_report() {
  local out="$RUN_DIR/report.md"
  local subs=0 alive=0 ports=0 urls=0 hist=0 js=0 findings=0 shodan=0 cloud=0 takeover=0 priority=0 normalized=0 added=0 removed=0
  [[ -f "$ASSETS_DIR/subdomains.txt" ]] && subs=$(wc -l < "$ASSETS_DIR/subdomains.txt")
  [[ -f "$ASSETS_DIR/alive.txt" ]] && alive=$(wc -l < "$ASSETS_DIR/alive.txt")
  [[ -f "$ASSETS_DIR/shodan.txt" ]] && shodan=$(wc -l < "$ASSETS_DIR/shodan.txt")
  [[ -f "$NETWORK_DIR/ports.txt" ]] && ports=$(wc -l < "$NETWORK_DIR/ports.txt")
  [[ -f "$WEB_DIR/urls.txt" ]] && urls=$(wc -l < "$WEB_DIR/urls.txt")
  [[ -f "$WEB_DIR/historical_urls.txt" ]] && hist=$(wc -l < "$WEB_DIR/historical_urls.txt")
  [[ -f "$WEB_DIR/javascript.txt" ]] && js=$(wc -l < "$WEB_DIR/javascript.txt")
  [[ -f "$FINDINGS_DIR/nuclei.jsonl" ]] && findings=$(wc -l < "$FINDINGS_DIR/nuclei.jsonl")
  [[ -f "$FINDINGS_DIR/cloud_candidates.txt" ]] && cloud=$(wc -l < "$FINDINGS_DIR/cloud_candidates.txt")
  [[ -f "$FINDINGS_DIR/takeover_candidates.txt" ]] && takeover=$(wc -l < "$FINDINGS_DIR/takeover_candidates.txt")
  [[ -f "$FINDINGS_DIR/prioritized_targets.txt" ]] && priority=$(wc -l < "$FINDINGS_DIR/prioritized_targets.txt")
  [[ -f "$RUN_DIR/assets.jsonl" ]] && normalized=$(wc -l < "$RUN_DIR/assets.jsonl")
  [[ -f "$RUN_DIR/changes.added.jsonl" ]] && added=$(wc -l < "$RUN_DIR/changes.added.jsonl")
  [[ -f "$RUN_DIR/changes.removed.jsonl" ]] && removed=$(wc -l < "$RUN_DIR/changes.removed.jsonl")
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
- Shodan enrichment rows: $shodan
- Open host/port entries: $ports
- Crawled URLs: $urls
- Historical URLs: $hist
- JavaScript URLs: $js
- Cloud-storage candidates: $cloud
- Takeover candidates: $takeover
- Nuclei findings: $findings
- Prioritized targets: $priority
- Normalized inventory records: $normalized
- Added records since baseline: $added
- Removed records since baseline: $removed

## Result locations
- Assets: \`assets/\`
- Web inventory: \`web/\`
- Network inventory: \`network/\`
- Findings: \`findings/\`
- Normalized inventory: \`assets.jsonl\`
- Change report: \`changes.md\`
- Baseline: \`baseline/assets.jsonl\`
- Screenshots: \`screenshots/\`
- Logs: \`logs/\`

Cloud/takeover outputs are candidate lists only. ApolloRE does not claim resources or access bucket objects.

> Use ApolloRE only against systems you own or have explicit authorization to assess.
EOF
}
