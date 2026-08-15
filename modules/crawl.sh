#!/usr/bin/env bash
run_crawl() {
  local alive="$ASSETS_DIR/alive.txt" raw="$WEB_DIR/urls.raw.txt" out="$WEB_DIR/urls.txt"
  stage_done "$out" && { log_info "Resume: crawl output already present"; return; }
  require_cmd katana || return 0
  [[ -s "$alive" ]] || { log_warn "No live URLs for crawler"; return 0; }
  katana -list "$alive" -silent -jc -d 2 -rl "$RATE_LIMIT" -o "$raw" || { log_warn "katana failed"; return 0; }
  filter_scope_urls "$raw" "$out"
  rm -f "$raw"
  log_info "Scoped crawled URLs: $(wc -l < "$out")"
}
