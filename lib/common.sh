#!/usr/bin/env bash

validate_domain() {
  local domain="$1"
  [[ ${#domain} -le 253 ]] || return 1
  [[ "$domain" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log_warn "Missing dependency '$1'; module will be skipped."; return 1; }
}

stage_done() {
  local file="$1"
  [[ "$RESUME" == true && -s "$file" ]]
}

normalize_scope_pattern() {
  local value="$1"
  value="${value%%#*}"
  value="${value//[[:space:]]/}"
  value="${value,,}"
  value="${value#http://}"; value="${value#https://}"
  value="${value%%/*}"; value="${value%%:*}"
  value="${value%.}"
  printf '%s' "$value"
}

validate_scope_pattern() {
  local pattern="$1" domain="$1"
  [[ "$pattern" == \*.* ]] && domain="${pattern#*.}"
  validate_domain "$domain"
}

prepare_scope() {
  local allow="$RUN_DIR/scope.txt" deny="$RUN_DIR/scope.exclude.txt"
  : > "$allow"; : > "$deny"

  if [[ -n "${SCOPE_FILE_INPUT:-}" ]]; then
    [[ -f "$SCOPE_FILE_INPUT" ]] || die "Scope file not found: $SCOPE_FILE_INPUT"
    while IFS= read -r line || [[ -n "$line" ]]; do
      local pattern
      pattern="$(normalize_scope_pattern "$line")"
      [[ -z "$pattern" ]] && continue
      validate_scope_pattern "$pattern" || die "Invalid scope entry: $line"
      printf '%s\n' "$pattern" >> "$allow"
    done < "$SCOPE_FILE_INPUT"
  else
    printf '%s\n' "$ROOT_DOMAIN" "*.$ROOT_DOMAIN" >> "$allow"
  fi

  if [[ -n "${EXCLUDE_FILE_INPUT:-}" ]]; then
    [[ -f "$EXCLUDE_FILE_INPUT" ]] || die "Exclude file not found: $EXCLUDE_FILE_INPUT"
    while IFS= read -r line || [[ -n "$line" ]]; do
      local pattern
      pattern="$(normalize_scope_pattern "$line")"
      [[ -z "$pattern" ]] && continue
      validate_scope_pattern "$pattern" || die "Invalid exclusion entry: $line"
      printf '%s\n' "$pattern" >> "$deny"
    done < "$EXCLUDE_FILE_INPUT"
  fi

  sort -u -o "$allow" "$allow"
  sort -u -o "$deny" "$deny"
  [[ -s "$allow" ]] || die "Resolved scope is empty"
}

scope_pattern_matches() {
  local host="${1,,}" pattern="${2,,}"
  if [[ "$pattern" == \*.* ]]; then
    local suffix="${pattern#*.}"
    [[ "$host" == *".$suffix" && "$host" != "$suffix" ]]
  else
    [[ "$host" == "$pattern" ]]
  fi
}

in_scope_host() {
  local host="${1,,}" pattern allowed=false
  host="${host%.}"
  [[ -f "$RUN_DIR/scope.txt" ]] || return 1

  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    if scope_pattern_matches "$host" "$pattern"; then allowed=true; break; fi
  done < "$RUN_DIR/scope.txt"
  "$allowed" || return 1

  if [[ -f "$RUN_DIR/scope.exclude.txt" ]]; then
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue
      scope_pattern_matches "$host" "$pattern" && return 1
    done < "$RUN_DIR/scope.exclude.txt"
  fi
  return 0
}

in_scope_url() {
  local url="$1" host
  host="${url#http://}"; host="${host#https://}"; host="${host%%/*}"; host="${host%%:*}"
  in_scope_host "$host"
}

filter_scope_hosts() {
  local input="$1" output="$2" host
  : > "$output"
  while IFS= read -r host; do
    host="${host#http://}"; host="${host#https://}"; host="${host%%/*}"; host="${host%%:*}"; host="${host%.}"
    in_scope_host "$host" && printf '%s\n' "$host"
  done < "$input"
  sort -u -o "$output" "$output"
}

filter_scope_urls() {
  local input="$1" output="$2" url
  : > "$output"
  while IFS= read -r url; do
    [[ -n "$url" ]] && in_scope_url "$url" && printf '%s\n' "$url"
  done < "$input"
  sort -u -o "$output" "$output"
}

append_exact_scope_hosts() {
  local output="$1" pattern
  [[ -f "$RUN_DIR/scope.txt" ]] || return 0
  while IFS= read -r pattern; do
    [[ -n "$pattern" && "$pattern" != \*.* ]] && printf '%s\n' "$pattern" >> "$output"
  done < "$RUN_DIR/scope.txt"
}

scope_roots() {
  local pattern
  [[ -f "$RUN_DIR/scope.txt" ]] || return 0
  while IFS= read -r pattern; do
    [[ "$pattern" == \*.* ]] && printf '%s\n' "${pattern#*.}"
  done < "$RUN_DIR/scope.txt"
  printf '%s\n' "$ROOT_DOMAIN"
}

trim_value() {
  local value="$1"
  value="${value#\"}"; value="${value%\"}"
  value="${value#\'}"; value="${value%\'}"
  printf '%s' "$value"
}

load_config() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  local key raw value
  while IFS='=' read -r key raw || [[ -n "${key:-}" ]]; do
    key="${key//[[:space:]]/}"
    [[ -z "$key" || "$key" == \#* ]] && continue
    value="$(trim_value "${raw:-}")"

    case "$key" in
      APOLLO_OUTPUT_BASE|APOLLO_RATE_LIMIT|APOLLO_USER_AGENT|NUCLEI_SEVERITIES|CVE_MAX_TECH_QUERIES|SUBFINDER_PROVIDER_CONFIG|SHODAN_API_KEY|NVD_API_KEY|WPSCAN_API_TOKEN|GITHUB_TOKEN)
        printf -v "$key" '%s' "$value"
        export "$key"
        ;;
      *) log_warn "Ignoring unsupported config key: $key" ;;
    esac
  done < "$file"

  log_info "Loaded config: $file"
}
