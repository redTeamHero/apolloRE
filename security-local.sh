#!/usr/bin/env bash
# Offline/local defensive assessment; does not launch network target scans.
set -Eeuo pipefail
umask 077
if [[ $# -ne 2 ]]; then
  echo "Usage: bash security-local.sh SOURCE_DIRECTORY OUTPUT_DIRECTORY" >&2
  exit 2
fi
source_dir="$(cd -- "$1" && pwd -P)"
mkdir -p -- "$2"
out="$(cd -- "$2" && pwd -P)"
if [[ "$out" == "$source_dir" || "$out" == "$source_dir/"* ]]; then
  echo "Output must be outside source directory" >&2
  exit 2
fi
run_dir="$(mktemp -d "$out/run-XXXXXXXX")"
status="$run_dir/status.tsv"
printf 'tool\tstatus\texit_code\n' > "$status"
run_check() {
  local tool="$1" rc=0
  shift
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s\tmissing\t127\n' "$tool" >> "$status"
    return
  fi
  "$@" > "$run_dir/$tool.stdout" 2> "$run_dir/$tool.stderr" || rc=$?
  printf '%s\t%s\t%s\n' "$tool" "$( [[ "$rc" == 0 ]] && echo completed || echo review_required )" "$rc" >> "$status"
}
run_check semgrep semgrep scan --config auto --metrics off --json --output "$run_dir/semgrep.json" "$source_dir"
run_check gitleaks gitleaks dir "$source_dir" --redact=100 --report-format json --report-path "$run_dir/gitleaks.json"
run_check trivy trivy fs --scanners vuln,misconfig --format json --output "$run_dir/trivy.json" "$source_dir"
run_check checkov checkov -d "$source_dir" -o json --output-file-path "$run_dir"
echo "Private assessment output: $run_dir"
cat "$status"
# Nonzero means assessment requires review, not necessarily a vulnerability.
awk -F '\t' 'NR>1 && $2!="completed" {bad=1} END {exit bad}' "$status"
