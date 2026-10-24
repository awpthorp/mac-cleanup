#!/usr/bin/env bash
# READ-ONLY. Lists node_modules folders in projects whose own files have not
# changed for N days (default 60). These are candidates to delete: the project's
# install command (npm/pnpm/yarn/bun install) rebuilds them when it is reopened.
#
# Skipped on purpose, because their node_modules belong to tools, not projects,
# and deleting them breaks editor extensions or global CLIs:
#   hidden folders directly under each root (~/.vscode, ~/.cursor, ~/.bun, ~/.config, ...),
#   ~/Library, app bundles (*.app), build output (.next), and nested node_modules.
#
# Usage: bash stale-node-modules.sh [days] [root ...]
# Output: "<KB>\t<path>" largest first on stdout; a TOTAL line on stderr.

set -u
DAYS=60
case "${1:-}" in ''|*[!0-9]*) ;; *) DAYS=$1; shift;; esac
[ $# -eq 0 ] && set -- "$HOME"

for root in "$@"; do
  root=${root%/}
  find "$root" -xdev -maxdepth 7 \
       \( -path "$root/.*" -o -path "$HOME/Library" -o -name '*.app' -o -name .Trash -o -name .next \) -prune -o \
       -name node_modules -type d -prune -print 2>/dev/null
done | sort -u | while IFS= read -r nm; do
  p=$(dirname "$nm")
  [ -f "$p/package.json" ] || continue
  case "$p" in */node_modules/*|*/.next|*/.next/*) continue;; esac
  # Active if any project file (outside dependency/build folders) changed recently.
  recent=$(find "$p" -maxdepth 6 \( -name node_modules -o -name .git -o -name .next -o -name dist -o -name build \) -prune -o \
           -type f -mtime -"$DAYS" -print 2>/dev/null | head -1)
  [ -z "$recent" ] && printf '%s\t%s\n' "$(du -sk "$nm" 2>/dev/null | cut -f1)" "$nm"
done | sort -rn | awk -F'\t' '{print; s+=$1} END{printf "TOTAL: %d stale node_modules, %.1f GB\n", NR, s/1048576 > "/dev/stderr"}'
