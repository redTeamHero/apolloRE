#!/usr/bin/env bash
run_prioritize() {
  local subs="$ASSETS_DIR/subdomains.txt" alive="$ASSETS_DIR/alive.txt" urls="$WEB_DIR/urls.txt" hist="$WEB_DIR/historical_urls.txt" out="$FINDINGS_DIR/prioritized_targets.txt"
  stage_done "$out" && { log_info "Resume: prioritized targets already present"; return; }
  local tmp="$FINDINGS_DIR/.priority.tmp"
  : > "$tmp"
  {
    [[ -s "$subs" ]] && cat "$subs"
    [[ -s "$alive" ]] && cat "$alive"
    [[ -s "$urls" ]] && cat "$urls"
    [[ -s "$hist" ]] && cat "$hist"
  } | awk '
    function score(s,   x) {
      x=tolower(s); n=0
      if (x ~ /(^|[.\/_-])(admin|administrator|dashboard|manage|management)([.\/_?-]|$)/) n+=5
      if (x ~ /(^|[.\/_-])(api|graphql|swagger|openapi)([.\/_?-]|$)/) n+=4
      if (x ~ /(^|[.\/_-])(dev|stage|staging|test|qa|uat|beta)([.\/_?-]|$)/) n+=4
      if (x ~ /(^|[.\/_-])(internal|intranet|corp|vpn|sso|auth|login)([.\/_?-]|$)/) n+=4
      if (x ~ /(^|[.\/_-])(jenkins|grafana|kibana|gitlab|jira|confluence)([.\/_?-]|$)/) n+=5
      if (x ~ /\.(json|yaml|yml|xml|env|bak|old|zip|tar|gz)([?#].*)?$/) n+=2
      return n
    }
    NF {s=score($0); if (s>0) print s "\t" $0}
  ' | sort -t $'\t' -k1,1nr -k2,2u > "$tmp"
  awk '!seen[$2]++ {print}' "$tmp" > "$out"
  rm -f "$tmp"
  log_info "Prioritized targets: $(wc -l < "$out")"
}
