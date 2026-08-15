#!/usr/bin/env bash
run_diff() {
  local current="$RUN_DIR/assets.jsonl"
  local baseline_dir="$RUN_DIR/baseline"
  local baseline="$baseline_dir/assets.jsonl"
  local report="$RUN_DIR/changes.md"
  local added="$RUN_DIR/changes.added.jsonl"
  local removed="$RUN_DIR/changes.removed.jsonl"
  mkdir -p "$baseline_dir"

  [[ -s "$current" ]] || { log_warn "No normalized inventory for diff module"; return 0; }

  if [[ ! -s "$baseline" ]]; then
    cp "$current" "$baseline"
    cat > "$report" <<EOF
# ApolloRE Change Report: $ROOT_DOMAIN

No previous baseline existed. The current normalized inventory has been saved as the baseline.
EOF
    : > "$added"; : > "$removed"
    log_info "Created initial baseline"
    return 0
  fi

  jq -S -c . "$current" | sort -u > "$RUN_DIR/.current.sorted"
  jq -S -c . "$baseline" | sort -u > "$RUN_DIR/.baseline.sorted"
  comm -13 "$RUN_DIR/.baseline.sorted" "$RUN_DIR/.current.sorted" > "$added"
  comm -23 "$RUN_DIR/.baseline.sorted" "$RUN_DIR/.current.sorted" > "$removed"

  local added_count removed_count
  added_count=$(wc -l < "$added")
  removed_count=$(wc -l < "$removed")

  cat > "$report" <<EOF
# ApolloRE Change Report: $ROOT_DOMAIN

Generated: $(date -u '+%Y-%m-%d %H:%M UTC')

- Added records: $added_count
- Removed records: $removed_count

## Added by type
EOF
  jq -r '.type' "$added" 2>/dev/null | sort | uniq -c | sort -nr | sed 's/^/- /' >> "$report" || true
  printf '\n## Removed by type\n' >> "$report"
  jq -r '.type' "$removed" 2>/dev/null | sort | uniq -c | sort -nr | sed 's/^/- /' >> "$report" || true
  printf '\n## Added examples\n' >> "$report"
  jq -r '"- ["+.type+"] "+.value' "$added" 2>/dev/null | head -n 50 >> "$report" || true
  printf '\n## Removed examples\n' >> "$report"
  jq -r '"- ["+.type+"] "+.value' "$removed" 2>/dev/null | head -n 50 >> "$report" || true

  cp "$current" "$baseline"
  rm -f "$RUN_DIR/.current.sorted" "$RUN_DIR/.baseline.sorted"
  log_info "Changes: +$added_count / -$removed_count; baseline updated"
}
