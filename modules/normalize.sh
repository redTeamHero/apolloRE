#!/usr/bin/env bash
run_normalize() {
  local out="$RUN_DIR/assets.jsonl"
  local tmp="$RUN_DIR/.assets.jsonl.tmp"
  : > "$tmp"

  emit_json() {
    local type="$1" value="$2" source="$3" extra="${4:-{}}"
    jq -cn --arg type "$type" --arg value "$value" --arg source "$source" --argjson extra "$extra" '{type:$type,value:$value,source:$source}+ $extra' >> "$tmp"
  }

  if [[ -f "$ASSETS_DIR/subdomains.txt" ]]; then
    while IFS= read -r host; do [[ -n "$host" ]] && emit_json host "$host" subdomains; done < "$ASSETS_DIR/subdomains.txt"
  fi

  if [[ -f "$ASSETS_DIR/alive.txt" ]]; then
    while IFS= read -r url; do [[ -n "$url" ]] && emit_json url "$url" http '{"alive":true}'; done < "$ASSETS_DIR/alive.txt"
  fi

  if [[ -f "$NETWORK_DIR/ports.txt" ]]; then
    while IFS= read -r hp; do
      [[ -n "$hp" ]] || continue
      host="${hp%:*}"; port="${hp##*:}"
      emit_json service "$hp" ports "$(jq -cn --arg host "$host" --argjson port "${port:-0}" '{host:$host,port:$port}')"
    done < "$NETWORK_DIR/ports.txt"
  fi

  if [[ -f "$WEB_DIR/urls.txt" ]]; then
    while IFS= read -r url; do [[ -n "$url" ]] && emit_json url "$url" crawl; done < "$WEB_DIR/urls.txt"
  fi

  if [[ -f "$WEB_DIR/historical_urls.txt" ]]; then
    while IFS= read -r url; do [[ -n "$url" ]] && emit_json url "$url" history '{"historical":true}'; done < "$WEB_DIR/historical_urls.txt"
  fi

  if [[ -f "$WEB_DIR/javascript.txt" ]]; then
    while IFS= read -r url; do [[ -n "$url" ]] && emit_json javascript "$url" javascript; done < "$WEB_DIR/javascript.txt"
  fi

  if [[ -f "$FINDINGS_DIR/cloud_candidates.txt" ]]; then
    while IFS= read -r value; do [[ -n "$value" ]] && emit_json cloud_candidate "$value" cloud; done < "$FINDINGS_DIR/cloud_candidates.txt"
  fi

  if [[ -f "$FINDINGS_DIR/takeover_candidates.txt" ]]; then
    while IFS= read -r value; do [[ -n "$value" ]] && emit_json takeover_candidate "$value" takeover; done < "$FINDINGS_DIR/takeover_candidates.txt"
  fi

  if [[ -f "$FINDINGS_DIR/nuclei.jsonl" ]]; then
    while IFS= read -r line; do
      jq -c '{type:"finding",value:(.matched_at // .host // .template_id // "unknown"),source:"nuclei",severity:(.info.severity // "unknown"),template:(.template_id // .template // "")}' <<< "$line" >> "$tmp" 2>/dev/null || true
    done < "$FINDINGS_DIR/nuclei.jsonl"
  fi

  jq -s 'unique_by([.type,.value,.source])[]' "$tmp" > "$out" 2>/dev/null || cp "$tmp" "$out"
  rm -f "$tmp"
  log_info "Normalized assets: $(wc -l < "$out" 2>/dev/null || echo 0)"
}
