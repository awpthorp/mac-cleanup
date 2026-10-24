#!/usr/bin/env bash
# mac-cleanup audit: READ-ONLY. Prints a sectioned report of disk, memory,
# startup items, apps and known space hogs. Never deletes or changes anything.
#
# Usage: bash audit.sh [--quick]
#   --quick  skip the slow per-folder sizing of the whole home directory
#
# Notes:
# - macOS has no `timeout` command by default, so nothing here relies on it.
# - Sizing a large home folder can take several minutes. Run in the background
#   and redirect to a file if your harness has a command time limit.
# - macOS may show privacy prompts for Desktop/Documents/Downloads/Photos.

set -u
QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

section() { printf '\n===== %s =====\n' "$1"; }
human() { awk '{ s=$1; u="K"; if (s>1024){s/=1024;u="M"} if (s>1024){s/=1024;u="G"} printf "%7.1f%s", s, u }'; }
size_of() { du -xsk "$1" 2>/dev/null | cut -f1; }
show_size() {
  # show_size <path> [label]: prints "<size>  <path>" if the path exists
  [ -e "$1" ] || return 0
  local k; k=$(size_of "$1"); [ -n "$k" ] || return 0
  printf '%s  %s\n' "$(echo "$k" | human)" "${2:-$1}"
}
DATA_VOL=/System/Volumes/Data
[ -d "$DATA_VOL" ] || DATA_VOL=/

section "SYSTEM"
sysctl -n machdep.cpu.brand_string 2>/dev/null
echo "RAM: $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
sw_vers 2>/dev/null | tr '\n' ' '; echo
uptime
echo "CPU cores: $(sysctl -n hw.ncpu)  (a load average well above this means the machine is saturated)"

section "DISK"
df -h "$DATA_VOL" | sed 1d | awk '{print "Size "$2"  Used "$3"  Free "$4"  ("$5" full)"}'
echo "-- APFS local snapshots (can hold deleted space until removed):"
snaps=$(tmutil listlocalsnapshots / 2>/dev/null | sed 1d)
[ -n "$snaps" ] && echo "$snaps" || echo "(none or not readable)"
echo "Note: df does not count 'purgeable' space, so Finder or Storage settings may show more free space."

section "MEMORY"
memory_pressure 2>/dev/null | tail -1
sysctl vm.swapusage

section "TOP PROCESSES BY CPU"
ps -Ao pid,%cpu,%mem,comm -r | head -16

section "TOP PROCESSES BY MEMORY (RSS MB)"
ps -Ao pid,rss,comm -m | awk 'NR==1{print "  PID     MB COMMAND"; next} NR<=16{printf "%5s %6.0f %s\n", $1, $2/1024, substr($0, index($0,$3))}'

section "LOGIN ITEMS"
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || echo "(could not read)"

section "LAUNCH AGENTS AND DAEMONS (non-Apple)"
for d in "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons; do
  echo "-- $d"
  ls "$d" 2>/dev/null | grep -v '^com\.apple\.' | while IFS= read -r f; do
    p="$d/$f"
    if ! /usr/libexec/PlistBuddy -c 'Print' "$p" >/dev/null 2>&1; then echo "   $f  (not readable without admin)"; continue; fi
    ral=$(/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' "$p" 2>/dev/null)
    if [ ! -r "$p" ]; then echo "   $f  (not readable without admin)"; continue; fi
    ka=$(/usr/libexec/PlistBuddy -c 'Print :KeepAlive' "$p" 2>/dev/null | head -1)
    case "$ka" in Dict*) ka=conditional;; esac
    prog=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$p" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Print :Program' "$p" 2>/dev/null)
    missing=""; [ -n "$prog" ] && [ "${prog:0:1}" = "/" ] && [ ! -e "$prog" ] && missing="  [program not found: likely orphan; check it is not on an unplugged drive]"
    echo "   $f  RunAtLoad=${ral:-no} KeepAlive=${ka:-no}${missing}"
  done
done
echo "-- Currently loaded non-Apple jobs (pid or -, status, label):"
launchctl list 2>/dev/null | awk 'NR>1 && $3 !~ /^com\.apple\./' | head -60

section "BACKGROUND ITEMS (System Settings > General > Login Items)"
# `sfltool dumpbtm` may ask for an admin password, so it only runs when already root.
if [ "$(id -u)" = 0 ]; then
  sfltool dumpbtm 2>/dev/null | awk '/^ *Name:/{n=$0} /Disposition:.*enabled/{if(n!=""){sub(/^ *Name: */,"",n); print "   " n}; n=""}' | sort -u | head -60
else
  echo "(skipped: needs admin. Full list: System Settings > General > Login Items & Extensions)"
fi

section "STUCK PRINT JOBS"
lpstat -o 2>/dev/null | head -10
[ -z "$(lpstat -o 2>/dev/null)" ] && echo "(none)"

section "BIGGEST APPS (with last-used date; 'never' may mean Spotlight has no record)"
for a in /Applications/* "$HOME/Applications"/*.app; do
  [ -d "$a" ] || continue; [ "$a" = /Applications/Utilities ] && continue
  k=$(size_of "$a"); [ -n "$k" ] || continue
  lu=$(mdls -raw -name kMDItemLastUsedDate "$a" 2>/dev/null | cut -c1-10)
  [ "$lu" = "(null)" ] && lu="never"
  printf '%s\t%s\t%s\n' "$k" "${lu:-unknown}" "$a"
done | sort -rn | head -40 | while IFS=$'\t' read -r k lu a; do printf '%s  last used %-10s  %s\n' "$(echo "$k" | human)" "$lu" "$a"; done

section "KNOWN SPACE HOGS (only paths that exist are shown; parent folders include their subfolders, so do not add rows up)"
L="$HOME/Library"
for p in \
  "$HOME/Downloads" "$HOME/.Trash" "$HOME/Desktop" "$HOME/Movies" \
  "$L/Caches" "$L/Logs" \
  "$L/Application Support/MobileSync/Backup" \
  "$L/Containers/com.apple.mail/Data/Library/Mail Downloads" \
  "$L/Developer/Xcode/DerivedData" "$L/Developer/Xcode/Archives" \
  "$L/Developer/Xcode/iOS DeviceSupport" "$L/Developer/CoreSimulator" \
  "$L/Containers/com.docker.docker" "$HOME/.docker" "$HOME/.colima" "$HOME/.orbstack" "$HOME/.lima" \
  "$HOME/.npm" "$HOME/.yarn" "$L/Caches/Yarn" "$L/pnpm" "$HOME/.bun/install/cache" \
  "$HOME/.cache" "$L/Caches/pip" "$HOME/.cache/uv" "$HOME/.cache/huggingface" "$HOME/.cache/puppeteer" \
  "$L/Caches/ms-playwright" "$HOME/.cargo/registry" "$HOME/.rustup" "$HOME/go/pkg/mod" \
  "$HOME/.gradle/caches" "$HOME/.m2/repository" "$L/Caches/CocoaPods" "$HOME/.android" \
  "$HOME/miniconda3/pkgs" "$HOME/anaconda3/pkgs" "$HOME/.conda/pkgs" \
  "$HOME/.ollama/models" "$HOME/.lmstudio" "$HOME/.platformio" \
  "$(brew --cache 2>/dev/null)" \
  "$HOME/.codex/worktrees" "$HOME/.grok/worktrees" "$HOME/.cursor/worktrees" "$HOME/.claude/worktrees" \
  "$L/Application Support/Claude/vm_bundles" \
  "$L/Application Support/Cursor/User/globalStorage" "$L/Application Support/Code/User/globalStorage" \
  "$L/Application Support/Code/CachedExtensionVSIXs" \
  "$L/Application Support/Steam/steamapps" \
  "$HOME/Library/Group Containers/group.com.apple.garageband10" "/Library/Application Support/GarageBand" \
  "/Library/Application Support/Logic" \
  ; do [ -n "$p" ] && show_size "$p"; done | grep -v ' [0-9.]*K  ' | sort -rh

section "LARGEST CACHE FOLDERS (~/Library/Caches)"
for d in "$L/Caches"/*; do k=$(size_of "$d"); [ -n "$k" ] && printf '%s\t%s\n' "$k" "$d"; done | sort -rn | head -15 | while IFS=$'\t' read -r k d; do printf '%s  %s\n' "$(echo "$k" | human)" "$d"; done

section "STEAM GAMES (size, last played)"
sa="$L/Application Support/Steam/steamapps"  # APFS is case-insensitive by default, so this also matches SteamApps
if [ -d "$sa" ]; then
  for f in "$sa"/appmanifest_*.acf; do
    [ -e "$f" ] || continue
    n=$(grep '"name"' "$f" | cut -d'"' -f4); dir=$(grep '"installdir"' "$f" | cut -d'"' -f4)
    [ -n "$dir" ] || continue
    lp=$(grep '"LastPlayed"' "$f" | cut -d'"' -f4); lpd=never; [ -n "$lp" ] && [ "$lp" != 0 ] && lpd=$(date -r "$lp" +%F)
    printf '%s  last played %s  %s\n' "$(size_of "$sa/common/$dir" | human)" "$lpd" "$n"
  done
fi

if [ "$QUICK" -eq 0 ]; then
  section "BIGGEST FOLDERS IN HOME (including hidden)"
  for d in "$HOME"/* "$HOME"/.[!.]*; do
    [ -L "$d" ] && continue; [ "$d" = "$HOME/Library" ] && continue
    k=$(size_of "$d"); [ -n "$k" ] && printf '%s\t%s\n' "$k" "$d"
  done | sort -rn | head -25 | while IFS=$'\t' read -r k d; do printf '%s  %s\n' "$(echo "$k" | human)" "$d"; done

  section "BIGGEST FOLDERS IN ~/Library/Application Support"
  for d in "$L/Application Support"/*; do k=$(size_of "$d"); [ -n "$k" ] && printf '%s\t%s\n' "$k" "$d"; done | sort -rn | head -15 | while IFS=$'\t' read -r k d; do printf '%s  %s\n' "$(echo "$k" | human)" "$d"; done

  section "USER DATA IN ~/Library (often what macOS calls 'System Data'; never delete without asking)"
  for p in "$L/Messages/Attachments" "$L/Containers" "$L/Group Containers" "$L/Mobile Documents" "$L/CloudStorage" "$L/Mail"; do show_size "$p"; done | sort -rh

  section "LARGE OLD FILES (>1GB, untouched 90+ days; libraries, VMs and hidden folders excluded)"
  find "$HOME" -xdev \( -path "$HOME/Library" -o -path "$HOME/.*" -o -name node_modules -o -name .git \
       -o -name '*.photoslibrary' -o -name '*.musiclibrary' -o -name '*.tvlibrary' -o -name '*.imovielibrary' \
       -o -name '*.fcpbundle' -o -name '*.lrlibrary' -o -name '*.lrdata' -o -name '*.pvm' -o -name '*.utm' -o -name '*.vmwarevm' \) -prune -o \
       -type f -size +1G -mtime +90 ! -name '*.lrcat*' -print 2>/dev/null | head -30 | while IFS= read -r f; do printf '%s  %s\n' "$(size_of "$f" | human)" "$f"; done
fi

section "DONE"
echo "Audit finished. Nothing was changed."
