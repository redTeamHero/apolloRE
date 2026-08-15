#!/usr/bin/env bash

validate_domain() { local d="$1"; [[ ${#d} -le 253 && "$d" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]; }
validate_ipv4() { local ip="$1" IFS=. p o; read -r -a p <<< "$ip"; [[ ${#p[@]} -eq 4 ]] || return 1; for o in "${p[@]}"; do [[ "$o" =~ ^[0-9]{1,3}$ ]] && ((10#$o<=255)) || return 1; done; }
validate_cidr() { local c="$1" ip="${1%/*}" pre="${1#*/}"; [[ "$c" == */* ]] && validate_ipv4 "$ip" && [[ "$pre" =~ ^[0-9]{1,2}$ ]] && ((pre<=32)); }
ipv4_to_int() { local a b c d; IFS=. read -r a b c d <<< "$1"; printf '%u' "$(((10#$a<<24)+(10#$b<<16)+(10#$c<<8)+10#$d))"; }
ip_in_cidr() { local ip="$1" c="$2" n="${2%/*}" p="${2#*/}" i ni m; validate_ipv4 "$ip" && validate_cidr "$c" || return 1; i=$(ipv4_to_int "$ip"); ni=$(ipv4_to_int "$n"); ((p==0)) && m=0 || m=$(((0xFFFFFFFF << (32-p)) & 0xFFFFFFFF)); (( (i&m)==(ni&m) )); }

require_cmd() { command -v "$1" >/dev/null 2>&1 || { log_warn "Missing dependency '$1'; module will be skipped."; return 1; }; }
stage_done() { [[ "$RESUME" == true && -s "$1" ]]; }

normalize_scope_pattern() { local v="$1"; v="${v%%#*}"; v="${v//[[:space:]]/}"; v="${v,,}"; v="${v#http://}"; v="${v#https://}"; v="${v%%/}"; v="${v%.}"; printf '%s' "$v"; }
validate_scope_pattern() { local p="$1"; [[ "$p" == \*.* ]] && validate_domain "${p#*.}" && return; validate_domain "$p" || validate_ipv4 "$p" || validate_cidr "$p"; }

prepare_scope() {
  local allow="$RUN_DIR/scope.txt" deny="$RUN_DIR/scope.exclude.txt" line pattern
  : > "$allow"; : > "$deny"
  if [[ -n "${SCOPE_FILE_INPUT:-}" ]]; then
    [[ -f "$SCOPE_FILE_INPUT" ]] || die "Scope file not found: $SCOPE_FILE_INPUT"
    while IFS= read -r line || [[ -n "$line" ]]; do pattern="$(normalize_scope_pattern "$line")"; [[ -z "$pattern" ]] && continue; validate_scope_pattern "$pattern" || die "Invalid scope entry: $line"; printf '%s\n' "$pattern" >> "$allow"; done < "$SCOPE_FILE_INPUT"
  else printf '%s\n' "$ROOT_DOMAIN" "*.$ROOT_DOMAIN" >> "$allow"; fi
  if [[ -n "${EXCLUDE_FILE_INPUT:-}" ]]; then
    [[ -f "$EXCLUDE_FILE_INPUT" ]] || die "Exclude file not found: $EXCLUDE_FILE_INPUT"
    while IFS= read -r line || [[ -n "$line" ]]; do pattern="$(normalize_scope_pattern "$line")"; [[ -z "$pattern" ]] && continue; validate_scope_pattern "$pattern" || die "Invalid exclusion entry: $line"; printf '%s\n' "$pattern" >> "$deny"; done < "$EXCLUDE_FILE_INPUT"
  fi
  sort -u -o "$allow" "$allow"; sort -u -o "$deny" "$deny"; [[ -s "$allow" ]] || die "Resolved scope is empty"
}

scope_pattern_matches() {
  local value="${1,,}" pattern="${2,,}"
  if validate_ipv4 "$value"; then
    validate_ipv4 "$pattern" && [[ "$value" == "$pattern" ]] && return 0
    validate_cidr "$pattern" && ip_in_cidr "$value" "$pattern" && return 0
    return 1
  fi
  validate_domain "$value" || return 1
  if [[ "$pattern" == \*.* ]]; then local suffix="${pattern#*.}"; [[ "$value" == *".$suffix" && "$value" != "$suffix" ]]
  elif validate_domain "$pattern"; then [[ "$value" == "$pattern" ]]
  else return 1; fi
}

in_scope_host() {
  local host="${1,,}" pattern allowed=false; host="${host%.}"
  while IFS= read -r pattern; do [[ -n "$pattern" ]] && scope_pattern_matches "$host" "$pattern" && { allowed=true; break; }; done < "$RUN_DIR/scope.txt"
  "$allowed" || return 1
  while IFS= read -r pattern; do [[ -n "$pattern" ]] && scope_pattern_matches "$host" "$pattern" && return 1; done < "$RUN_DIR/scope.exclude.txt"
  return 0
}

extract_target_host() { local v="$1"; v="${v#http://}"; v="${v#https://}"; v="${v%%/*}"; v="${v%%:*}"; printf '%s' "${v%.}"; }
in_scope_url() { in_scope_host "$(extract_target_host "$1")"; }
filter_scope_hosts() { local input="$1" output="$2" h; : > "$output"; while IFS= read -r h; do h="$(extract_target_host "$h")"; in_scope_host "$h" && printf '%s\n' "$h"; done < "$input"; sort -u -o "$output" "$output"; }
filter_scope_urls() { local input="$1" output="$2" u; : > "$output"; while IFS= read -r u; do [[ -n "$u" ]] && in_scope_url "$u" && printf '%s\n' "$u"; done < "$input"; sort -u -o "$output" "$output"; }
append_exact_scope_hosts() { local out="$1" p; while IFS= read -r p; do (validate_domain "$p" || validate_ipv4 "$p") && printf '%s\n' "$p" >> "$out"; done < "$RUN_DIR/scope.txt"; }
scope_roots() { local p; while IFS= read -r p; do [[ "$p" == \*.* ]] && printf '%s\n' "${p#*.}"; done < "$RUN_DIR/scope.txt"; printf '%s\n' "$ROOT_DOMAIN"; }
scope_ip_targets() { local p; while IFS= read -r p; do (validate_ipv4 "$p" || validate_cidr "$p") && printf '%s\n' "$p"; done < "$RUN_DIR/scope.txt" | sort -u; }

trim_value() { local v="$1"; v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"; printf '%s' "$v"; }
load_config() { local file="$1" key raw value; [[ -f "$file" ]] || return 0; while IFS='=' read -r key raw || [[ -n "${key:-}" ]]; do key="${key//[[:space:]]/}"; [[ -z "$key" || "$key" == \#* ]] && continue; value="$(trim_value "${raw:-}")"; case "$key" in APOLLO_OUTPUT_BASE|APOLLO_RATE_LIMIT|APOLLO_USER_AGENT|NUCLEI_SEVERITIES|CVE_MAX_TECH_QUERIES|SUBFINDER_PROVIDER_CONFIG|SHODAN_API_KEY|NVD_API_KEY|WPSCAN_API_TOKEN|GITHUB_TOKEN) printf -v "$key" '%s' "$value"; export "$key";; *) log_warn "Ignoring unsupported config key: $key";; esac; done < "$file"; log_info "Loaded config: $file"; }
