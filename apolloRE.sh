#!/usr/bin/env bash
set -Eeuo pipefail

APOLLO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export APOLLO_DIR
export PATH="$HOME/.local/bin:$PATH"

# shellcheck source=lib/logging.sh
source "$APOLLO_DIR/lib/logging.sh"
# shellcheck source=lib/common.sh
source "$APOLLO_DIR/lib/common.sh"

ORIGINAL_ARGS=("$@")
ROOT_DOMAIN=""
MODE="full"
MODULES=""
RESUME=false
VERBOSE=false
CONFIG_FILE="${APOLLO_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/apollore/config.env}"

# Discover --config before loading defaults.
for ((i=0; i<${#ORIGINAL_ARGS[@]}; i++)); do
  if [[ "${ORIGINAL_ARGS[$i]}" == "--config" ]]; then
    CONFIG_FILE="${ORIGINAL_ARGS[$((i+1))]:-}"
  fi
done

load_config "$CONFIG_FILE"

RATE_LIMIT="${APOLLO_RATE_LIMIT:-50}"
OUTPUT_BASE="${APOLLO_OUTPUT_BASE:-$PWD/results}"
NUCLEI_SEVERITIES="${NUCLEI_SEVERITIES:-low,medium,high,critical}"
APOLLO_USER_AGENT="${APOLLO_USER_AGENT:-ApolloRE/2.0}"
export NUCLEI_SEVERITIES APOLLO_USER_AGENT

usage() {
  cat <<'EOF'
ApolloRE v2 - authorized reconnaissance orchestrator

Usage:
  ./apolloRE.sh -d example.com [options]

Options:
  -d, --domain DOMAIN       Root domain in authorized scope (required)
  -m, --mode MODE           passive | web | full (default: full)
      --modules LIST        Comma-separated modules
      --rate-limit N        Requests/second hint for supported tools
      --config FILE         Config file (default: ~/.config/apollore/config.env)
      --resume              Skip stages whose expected output already exists
  -o, --output DIR          Base results directory
  -v, --verbose             Verbose logging
  -h, --help                Show help

Examples:
  ./apolloRE.sh -d example.com --mode passive
  ./apolloRE.sh -d example.com --mode web --rate-limit 25
  ./apolloRE.sh -d example.com --config ~/.config/apollore/config.env --resume
  ./apolloRE.sh -d example.com --modules subdomains,http,dns,report

Only scan systems you own or have explicit authorization to test.
EOF
}

set -- "${ORIGINAL_ARGS[@]}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain) ROOT_DOMAIN="${2:-}"; shift 2 ;;
    -m|--mode) MODE="${2:-}"; shift 2 ;;
    --modules) MODULES="${2:-}"; shift 2 ;;
    --rate-limit) RATE_LIMIT="${2:-}"; shift 2 ;;
    --config) CONFIG_FILE="${2:-}"; shift 2 ;;
    --resume) RESUME=true; shift ;;
    -o|--output) OUTPUT_BASE="${2:-}"; shift 2 ;;
    -v|--verbose) VERBOSE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown option: $1"; usage; exit 2 ;;
  esac
done

[[ -n "$ROOT_DOMAIN" ]] || { log_error "A root domain is required."; usage; exit 2; }
validate_domain "$ROOT_DOMAIN" || die "Invalid domain: $ROOT_DOMAIN"
[[ "$RATE_LIMIT" =~ ^[0-9]+$ ]] && (( RATE_LIMIT > 0 )) || die "--rate-limit must be a positive integer"
case "$MODE" in passive|web|full) ;; *) die "Invalid mode: $MODE" ;; esac

export ROOT_DOMAIN MODE RESUME VERBOSE RATE_LIMIT CONFIG_FILE
export RUN_DIR="$OUTPUT_BASE/$ROOT_DOMAIN"
export ASSETS_DIR="$RUN_DIR/assets"
export WEB_DIR="$RUN_DIR/web"
export NETWORK_DIR="$RUN_DIR/network"
export FINDINGS_DIR="$RUN_DIR/findings"
export SCREENSHOTS_DIR="$RUN_DIR/screenshots"
export LOG_DIR="$RUN_DIR/logs"
mkdir -p "$ASSETS_DIR" "$WEB_DIR" "$NETWORK_DIR" "$FINDINGS_DIR" "$SCREENSHOTS_DIR" "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/apollore.log") 2>&1

write_scope_file
log_info "ApolloRE v2 starting for $ROOT_DOMAIN"
log_info "Mode=$MODE rate_limit=$RATE_LIMIT resume=$RESUME output=$RUN_DIR"
[[ -n "${SHODAN_API_KEY:-}" ]] && log_info "Shodan API key available via environment/config"
[[ -n "${WPSCAN_API_TOKEN:-}" ]] && log_info "WPScan API token available via environment/config"
[[ -n "${GITHUB_TOKEN:-}" ]] && log_info "GitHub token available via environment/config"
[[ -n "${SUBFINDER_PROVIDER_CONFIG:-}" ]] && log_info "Subfinder provider config: $SUBFINDER_PROVIDER_CONFIG"

if [[ -n "$MODULES" ]]; then
  IFS=',' read -r -a pipeline <<< "$MODULES"
else
  case "$MODE" in
    passive) pipeline=(subdomains dns http report) ;;
    web) pipeline=(subdomains http crawl javascript screenshots report) ;;
    full) pipeline=(subdomains dns http ports crawl javascript nuclei screenshots report) ;;
  esac
fi

for module in "${pipeline[@]}"; do
  module="${module//[[:space:]]/}"
  [[ "$module" =~ ^[a-z]+$ ]] || die "Invalid module name: $module"
  module_file="$APOLLO_DIR/modules/$module.sh"
  [[ -f "$module_file" ]] || die "Unknown module: $module"
  log_info "Running module: $module"
  # shellcheck source=/dev/null
  source "$module_file"
  "run_${module}"
done

log_info "ApolloRE finished. Results: $RUN_DIR"
