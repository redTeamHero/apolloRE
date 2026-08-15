#!/usr/bin/env bash
run_javascript() {
  local urls="$WEB_DIR/urls.txt" alive="$ASSETS_DIR/alive.txt" out="$WEB_DIR/javascript.txt"
  stage_done "$out" && { log_info "Resume: JavaScript inventory already present"; return; }
  : > "$out"
  if [[ -s "$urls" ]]; then
    grep -Eai '\.js([?#].*)?$' "$urls" | sort -u > "$out" || true
  fi
  if command -v subjs >/dev/null 2>&1 && [[ -s "$alive" ]]; then
    subjs -i "$alive" 2>/dev/null >> "$out" || true
    sort -u -o "$out" "$out"
  fi
  log_info "JavaScript URLs: $(wc -l < "$out")"
}
