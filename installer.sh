#!/usr/bin/env bash
set -Eeuo pipefail

MODE="core"
NO_APT=false
CHECK_ONLY=false

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; RESET='\033[0m'
info() { printf "%b[*]%b %s\n" "$GREEN" "$RESET" "$*"; }
warn() { printf "%b[!]%b %s\n" "$YELLOW" "$RESET" "$*"; }
err()  { printf "%b[-]%b %s\n" "$RED" "$RESET" "$*" >&2; }

usage() {
  cat <<'EOF'
ApolloRE v2 installer (Debian/Kali/Ubuntu)

Usage:
  ./installer.sh [--core|--all] [--no-apt] [--check]

Options:
  --core     Install standard ApolloRE pipeline tools (default)
  --all      Install core tools plus optional screenshot/browser tooling
  --no-apt   Do not install OS packages
  --check    Only report dependency status; make no changes
  -h,--help  Show help

The installer does NOT run a full system upgrade and does not configure API keys.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --core) MODE="core"; shift ;;
    --all) MODE="all"; shift ;;
    --no-apt) NO_APT=true; shift ;;
    --check) CHECK_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 2 ;;
  esac
done

export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
have() { command -v "$1" >/dev/null 2>&1; }

version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

check_status() {
  local tools=(subfinder httpx naabu katana nuclei dig gau waybackurls shodan jq)
  [[ "$MODE" == "all" ]] && tools+=(gowitness chromium chromium-browser)
  info "Dependency status"
  for tool in "${tools[@]}"; do
    if have "$tool"; then printf '  [ok] %s -> %s\n' "$tool" "$(command -v "$tool")"; else printf '  [--] %s\n' "$tool"; fi
  done
}

if "$CHECK_ONLY"; then
  check_status
  exit 0
fi

if ! "$NO_APT"; then
  have apt-get || { err "apt-get not found. Re-run with --no-apt and install prerequisites manually."; exit 1; }
  info "Refreshing apt package metadata"
  sudo apt-get update

  base_packages=(ca-certificates curl git jq dnsutils libpcap-dev golang-go pipx)
  [[ "$MODE" == "all" ]] && base_packages+=(chromium)

  info "Installing OS prerequisites: ${base_packages[*]}"
  if ! sudo apt-get install -y "${base_packages[@]}"; then
    warn "One or more apt packages failed. Continuing so existing tools can still be validated."
  fi
fi

have go || { err "Go is required to install ApolloRE's core tools."; exit 1; }
GO_VERSION="$(go version | awk '{print $3}' | sed 's/^go//')"
info "Detected Go $GO_VERSION"
if ! version_ge "$GO_VERSION" "1.25"; then
  err "Go 1.25+ is recommended for current ProjectDiscovery releases. Upgrade Go, then rerun installer.sh."
  exit 1
fi

install_go_tool() {
  local name="$1" package="$2"
  if have "$name"; then
    info "$name already installed: $(command -v "$name")"
    return 0
  fi
  info "Installing $name"
  if GOBIN="$HOME/.local/bin" go install -v "$package"; then
    have "$name" && info "$name installed successfully" || warn "$name built but is not visible in PATH"
  else
    warn "Failed to install $name"
  fi
}

mkdir -p "$HOME/.local/bin"

install_go_tool subfinder 'github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest'
install_go_tool httpx 'github.com/projectdiscovery/httpx/cmd/httpx@latest'
install_go_tool naabu 'github.com/projectdiscovery/naabu/v2/cmd/naabu@latest'
install_go_tool katana 'github.com/projectdiscovery/katana/cmd/katana@latest'
install_go_tool nuclei 'github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest'
install_go_tool gau 'github.com/lc/gau/v2/cmd/gau@latest'
install_go_tool waybackurls 'github.com/tomnomnom/waybackurls@latest'

if [[ "$MODE" == "all" ]]; then
  install_go_tool gowitness 'github.com/sensepost/gowitness@latest'
fi

if ! have shodan; then
  if have pipx; then
    info "Installing Shodan CLI with pipx"
    pipx install shodan >/dev/null 2>&1 || warn "Failed to install Shodan CLI"
  else
    warn "pipx unavailable; install the Shodan CLI manually if you want Shodan enrichment"
  fi
fi

if have nuclei; then
  info "Updating Nuclei templates"
  nuclei -ut >/dev/null 2>&1 || warn "Could not update Nuclei templates"
fi

printf '\n'
check_status
printf '\n'
info "Installer finished. Ensure $HOME/.local/bin is in PATH."
info "Copy config/apollo.env.example to ~/.config/apollore/config.env to configure API keys."
