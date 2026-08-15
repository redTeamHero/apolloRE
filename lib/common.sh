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

write_scope_file() {
  printf '%s\n' "$ROOT_DOMAIN" "*.$ROOT_DOMAIN" > "$RUN_DIR/scope.txt"
}

in_scope_host() {
  local host="${1,,}"
  local root="${ROOT_DOMAIN,,}"
  [[ "$host" == "$root" || "$host" == *".$root" ]]
}

filter_scope_hosts() {
  local input="$1" output="$2"
  : > "$output"
  while IFS= read -r host; do
    host="${host#http://}"; host="${host#https://}"; host="${host%%/*}"; host="${host%%:*}"
    in_scope_host "$host" && printf '%s\n' "$host"
  done < "$input"
  sort -u -o "$output" "$output"
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
