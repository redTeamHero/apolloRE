#!/usr/bin/env bash
run_http() {
  local subs="$ASSETS_DIR/subdomains.txt" targets="$ASSETS_DIR/http_targets.txt" alive_raw="$ASSETS_DIR/alive.raw.txt" alive="$ASSETS_DIR/alive.txt" meta_raw="$WEB_DIR/http.raw.jsonl" meta="$WEB_DIR/http.jsonl"
  stage_done "$alive" && { log_info "Resume: HTTP targets already present"; return; }
  : > "$targets"; [[ -s "$subs" ]] && cat "$subs" >> "$targets"
  while IFS= read -r p; do validate_ipv4 "$p" && printf '%s\n' "$p" >> "$targets"; done < "$RUN_DIR/scope.txt"
  sort -u -o "$targets" "$targets"
  [[ -s "$targets" ]] || { log_warn "No scoped hosts/IPs for HTTP probing"; return 0; }
  local httpx_cmd=""; command -v httpx >/dev/null 2>&1 && httpx_cmd=httpx; command -v httpx-toolkit >/dev/null 2>&1 && httpx_cmd=httpx-toolkit
  [[ -n "$httpx_cmd" ]] || { log_warn "Missing httpx/httpx-toolkit"; return 0; }
  local common=(-silent -l "$targets" -rl "$RATE_LIMIT"); [[ -n "${APOLLO_USER_AGENT:-}" ]] && common+=(-H "User-Agent: $APOLLO_USER_AGENT")
  "$httpx_cmd" "${common[@]}" -o "$alive_raw" || { log_warn "httpx probe failed"; return 0; }
  filter_scope_urls "$alive_raw" "$alive"; rm -f "$alive_raw"
  "$httpx_cmd" "${common[@]}" -json -status-code -title -tech-detect -web-server -ip -o "$meta_raw" 2>/dev/null || true
  if command -v jq >/dev/null 2>&1 && [[ -s "$meta_raw" ]]; then
    jq -c --argfile /dev/null /dev/null 2>/dev/null >/dev/null || true
    : > "$meta"; while IFS= read -r line; do url=$(printf '%s' "$line" | jq -r '.url // .input // empty' 2>/dev/null); [[ -n "$url" ]] && in_scope_url "$url" && printf '%s\n' "$line" >> "$meta"; done < "$meta_raw"
  else cp -f "$meta_raw" "$meta" 2>/dev/null || true; fi
  rm -f "$meta_raw"
}
