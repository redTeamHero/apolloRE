#!/usr/bin/env bash
run_http() {
  local subs="$ASSETS_DIR/subdomains.txt" alive="$ASSETS_DIR/alive.txt" meta="$WEB_DIR/http.jsonl"
  stage_done "$alive" && { log_info "Resume: HTTP targets already present"; return; }
  [[ -s "$subs" ]] || { log_warn "No subdomains for HTTP probing"; return 0; }

  local httpx_cmd=""
  command -v httpx >/dev/null 2>&1 && httpx_cmd=httpx
  command -v httpx-toolkit >/dev/null 2>&1 && httpx_cmd=httpx-toolkit
  [[ -n "$httpx_cmd" ]] || { log_warn "Missing httpx/httpx-toolkit"; return 0; }

  local common=(-silent -l "$subs" -rl "$RATE_LIMIT")
  [[ -n "${APOLLO_USER_AGENT:-}" ]] && common+=(-H "User-Agent: $APOLLO_USER_AGENT")

  "$httpx_cmd" "${common[@]}" -o "$alive" || { log_warn "httpx probe failed"; return 0; }
  "$httpx_cmd" "${common[@]}" -json -status-code -title -tech-detect -web-server -ip -o "$meta" 2>/dev/null || true
}
