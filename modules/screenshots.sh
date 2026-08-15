#!/usr/bin/env bash
run_screenshots() {
  local alive="$ASSETS_DIR/alive.txt"
  [[ -s "$alive" ]] || { log_warn "No live URLs for screenshots"; return 0; }
  if command -v gowitness >/dev/null 2>&1; then
    gowitness scan file -f "$alive" --screenshot-path "$SCREENSHOTS_DIR" >/dev/null 2>&1 || log_warn "gowitness failed"
  elif command -v aquatone >/dev/null 2>&1; then
    (cd "$SCREENSHOTS_DIR" && aquatone -silent -threads 3 < "$alive") || log_warn "aquatone failed"
  else
    log_warn "No screenshot tool installed (gowitness/aquatone)"
  fi
}
