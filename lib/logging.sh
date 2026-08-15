#!/usr/bin/env bash

_log() {
  local level="$1"; shift
  printf '%s %-5s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
}
log_info()  { _log INFO "$@"; }
log_warn()  { _log WARN "$@"; }
log_error() { _log ERROR "$@" >&2; }
die() { log_error "$*"; exit 1; }
