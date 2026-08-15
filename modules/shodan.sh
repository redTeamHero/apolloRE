#!/usr/bin/env bash
run_shodan() {
  local out="$ASSETS_DIR/shodan.txt" raw="$ASSETS_DIR/shodan.raw.txt"
  stage_done "$out" && { log_info "Resume: Shodan enrichment already present"; return; }
  [[ -n "${SHODAN_API_KEY:-}" ]] || { log_warn "SHODAN_API_KEY not configured; skipping Shodan"; return 0; }
  require_cmd shodan || return 0
  : > "$raw"; : > "$out"

  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    SHODAN_API_KEY="$SHODAN_API_KEY" shodan search --fields hostnames,ip_str,port,org,product "hostname:$root" 2>/dev/null >> "$raw" || log_warn "Shodan search failed for $root"
  done < <(scope_roots | sort -u)

  while IFS=$'\t' read -r hostnames ip port org product; do
    [[ -n "$hostnames" ]] || continue
    local matched=false h
    IFS=',' read -r -a host_array <<< "$hostnames"
    for h in "${host_array[@]}"; do
      h="${h//[[:space:]]/}"
      if in_scope_host "$h"; then matched=true; break; fi
    done
    "$matched" && printf '%s\t%s\t%s\t%s\t%s\n' "$hostnames" "$ip" "$port" "$org" "$product" >> "$out"
  done < "$raw"

  sort -u -o "$out" "$out"
  rm -f "$raw"
  log_info "Scoped Shodan rows: $(wc -l < "$out")"
}
