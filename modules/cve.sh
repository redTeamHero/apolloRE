#!/usr/bin/env bash

run_cve() {
  local candidates="$FINDINGS_DIR/cve_candidates.jsonl"
  local detected="$FINDINGS_DIR/cve_detected.jsonl"
  local techs="$WEB_DIR/technologies.txt"
  local alive="$ASSETS_DIR/alive.txt"
  local max_queries="${CVE_MAX_TECH_QUERIES:-8}"

  require_cmd jq || return 0
  require_cmd curl || return 0
  : > "$candidates"
  : > "$detected"

  nvd_request() {
    local url="$1"
    local -a args=(curl -fsS --retry 2 --connect-timeout 10 --max-time 30 -H "User-Agent: $APOLLO_USER_AGENT")
    [[ -n "${NVD_API_KEY:-}" ]] && args+=( -H "apiKey: ${NVD_API_KEY}" )
    "${args[@]}" "$url"
  }

  emit_nvd_candidates() {
    local query_label="$1"
    jq -c --arg query "$query_label" '
      .vulnerabilities[]?.cve as $cve |
      {
        type:"cve_candidate",
        cve:$cve.id,
        status:"correlated",
        correlation:$query,
        source:"nvd",
        published:($cve.published // null),
        last_modified:($cve.lastModified // null),
        description:([ $cve.descriptions[]? | select(.lang=="en") | .value ][0] // ""),
        severity:(
          $cve.metrics.cvssMetricV40[0].cvssData.baseSeverity //
          $cve.metrics.cvssMetricV31[0].cvssData.baseSeverity //
          $cve.metrics.cvssMetricV30[0].cvssData.baseSeverity //
          $cve.metrics.cvssMetricV2[0].baseSeverity // "UNKNOWN"
        )
      }
    '
  }

  if [[ -n "${CVE_ID:-}" ]]; then
    if body="$(nvd_request "https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=$CVE_ID" 2>/dev/null)"; then
      emit_nvd_candidates "explicit:$CVE_ID" <<< "$body" >> "$candidates" || true
    else
      log_warn "NVD lookup failed for $CVE_ID"
    fi
  else
    : > "$techs"
    if [[ -s "$WEB_DIR/http.jsonl" ]]; then
      jq -r '(.tech // [])[]?, (.webserver // empty)' "$WEB_DIR/http.jsonl" 2>/dev/null |
        sed -E 's/^[[:space:]]+|[[:space:]]+$//g' |
        grep -Ev '^$' | sort -u | head -n "$max_queries" > "$techs" || true
    fi

    local delay=6
    [[ -n "${NVD_API_KEY:-}" ]] && delay=1

    while IFS= read -r tech; do
      [[ -n "$tech" ]] || continue
      local query encoded body
      query="${tech//:/ }"
      encoded="$(jq -rn --arg v "$query" '$v|@uri')"
      log_info "NVD correlation: $query"
      if body="$(nvd_request "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=$encoded&resultsPerPage=20" 2>/dev/null)"; then
        emit_nvd_candidates "technology:$tech" <<< "$body" | head -n 20 >> "$candidates" || true
      else
        log_warn "NVD lookup failed for technology: $tech"
      fi
      sleep "$delay"
    done < "$techs"
  fi

  if [[ -s "$candidates" ]]; then
    jq -s 'unique_by(.cve,.correlation)[]' "$candidates" > "$candidates.tmp" 2>/dev/null && mv "$candidates.tmp" "$candidates"
  fi

  if ! command -v nuclei >/dev/null 2>&1; then
    log_warn "nuclei not installed; CVE correlation completed without active verification"
    return 0
  fi
  [[ -s "$alive" ]] || { log_warn "No live URLs for CVE checks"; return 0; }

  local -a cmd=(
    nuclei -l "$alive"
    -tags cve
    -severity "$NUCLEI_SEVERITIES"
    -rl "$RATE_LIMIT"
    -silent -jsonl
    -disable-unsigned-templates
    -exclude-tags fuzz,dos
    -H "User-Agent: $APOLLO_USER_AGENT"
    -o "$detected"
  )

  case "${CVE_PROFILE:-safe}" in
    safe)
      cmd+=( -type http,dns,ssl,tcp )
      log_info "Running safe CVE verification profile"
      ;;
    expanded)
      # Broader signed-template coverage, but no opt-in to code/headless/fuzz
      # execution and no unsigned or DoS/fuzz-tagged templates.
      log_info "Running expanded CVE verification profile"
      ;;
  esac

  [[ -n "${CVE_ID:-}" ]] && cmd+=( -id "$CVE_ID" )
  "${cmd[@]}" || log_warn "CVE verification completed with errors"

  log_info "CVE candidates: $(wc -l < "$candidates" 2>/dev/null || echo 0)"
  log_info "CVE detections: $(wc -l < "$detected" 2>/dev/null || echo 0)"
}
