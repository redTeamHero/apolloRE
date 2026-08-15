#!/usr/bin/env bash
run_nuclei() {
  local alive="$ASSETS_DIR/alive.txt" out="$FINDINGS_DIR/nuclei.jsonl"
  stage_done "$out" && { log_info "Resume: nuclei findings already present"; return; }
  require_cmd nuclei || return 0
  [[ -s "$alive" ]] || { log_warn "No live URLs for nuclei"; return 0; }

  local args=(-l "$alive" -rl "$RATE_LIMIT" -severity "$NUCLEI_SEVERITIES" -jsonl -o "$out")
  [[ -n "${APOLLO_USER_AGENT:-}" ]] && args+=(-H "User-Agent: $APOLLO_USER_AGENT")
  nuclei "${args[@]}" || log_warn "nuclei completed with errors"
}
