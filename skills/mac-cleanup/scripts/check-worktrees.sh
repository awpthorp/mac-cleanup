#!/usr/bin/env bash
# READ-ONLY. For every git checkout under a folder, report whether deleting it
# could lose work. Use this before removing any AI-agent worktree or old clone.
#
# Usage: bash check-worktrees.sh [folder ...]
#   Default folders: ~/.codex/worktrees ~/.grok/worktrees ~/.cursor/worktrees ~/.claude/worktrees,
#   plus every <repo>/.claude/worktrees found under your home folder (where Claude Code keeps them).
#
# Output: VERDICT  size  modified  kind  changes=N  env_only_here=N  stashes=N  unpushed=N  branch  path
#   SAFE   nothing would be lost: no modified or new files, and every commit exists elsewhere
#          (linked worktree: on a branch in the main repo and pushed if it tracks a remote;
#           clone: every commit on the remote)
#   KEEP   something would be lost; show the user before touching it
#          (includes .env-style files that exist only in this checkout: gitignored, so
#          `git status` misses them, but removing the worktree deletes them)
#   NOGIT  folder with no git checkout inside; look at its contents before deleting
#
# A linked worktree has a .git FILE (its history lives in the main repo).
# A standalone clone has a .git DIRECTORY (deleting it deletes its history).

set -u
if [ $# -eq 0 ]; then
  set -- "$HOME/.codex/worktrees" "$HOME/.grok/worktrees" "$HOME/.cursor/worktrees" "$HOME/.claude/worktrees"
  while IFS= read -r d; do set -- "$@" "$d"; done < <(find "$HOME" -xdev -maxdepth 6 \( -path "$HOME/Library" -o -name node_modules \) -prune -o -type d -path '*/.claude/worktrees' -print 2>/dev/null)
fi

# Count .env-style files in a checkout that are real files (not symlinks) and are
# missing from, or different to, the same file in the repo's main checkout.
unique_env() {
  local r=$1 main n=0 f
  main=$(git -C "$r" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
  while IFS= read -r f; do
    [ -L "$r/$f" ] && continue
    if [ -n "$main" ] && [ "$main" != "$r" ] && [ -f "$main/$f" ] && cmp -s "$r/$f" "$main/$f"; then continue; fi
    n=$((n+1))
  done < <(cd "$r" && find . -maxdepth 3 \( -name node_modules -o -name .git \) -prune -o \( -name '.env' -o -name '.env.*' -o -name '.dev.vars' \) -type f -print 2>/dev/null | sed 's|^\./||')
  echo "$n"
}

for root in "$@"; do
  [ -d "$root" ] || continue
  echo "== $root"
  find "$root" -maxdepth 4 -name .git 2>/dev/null | while IFS= read -r g; do
    r=$(dirname "$g")
    # Modified, staged AND new (untracked) files; ignored files such as node_modules are skipped.
    changes=$(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    br=$(git -C "$r" branch --show-current 2>/dev/null); br=${br:-detached}
    verdict=SAFE
    if [ -d "$g" ]; then
      kind=clone
      # Every local commit must exist on a remote, and nothing stashed.
      unpushed=$(git -C "$r" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
      onremote=$(git -C "$r" branch -r --contains HEAD 2>/dev/null | wc -l | tr -d ' ')
      stashes=$(git -C "$r" stash list 2>/dev/null | wc -l | tr -d ' ')
      { [ "$unpushed" -gt 0 ] || [ "$onremote" -eq 0 ] || [ "$stashes" -gt 0 ]; } && verdict=KEEP
    else
      kind=worktree
      # History lives in the main repo; HEAD must be on some branch there.
      stashes=0
      onbr=$(git -C "$r" branch -a --contains HEAD 2>/dev/null | grep -vc 'HEAD detached')
      unpushed=0
      git -C "$r" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 && unpushed=$(git -C "$r" log --oneline '@{u}..HEAD' 2>/dev/null | wc -l | tr -d ' ')
      { [ "$onbr" -eq 0 ] || [ "$unpushed" -gt 0 ]; } && verdict=KEEP
    fi
    envs=$(unique_env "$r")
    { [ "$changes" -gt 0 ] || [ "$envs" -gt 0 ]; } && verdict=KEEP
    printf '%-5s  %6s  %s  %-8s  changes=%s  env_only_here=%s  stashes=%s  unpushed=%s  %s  %s\n' \
      "$verdict" "$(du -sh "$r" 2>/dev/null | cut -f1)" "$(stat -f %Sm -t %F "$r")" "$kind" \
      "$changes" "$envs" "$stashes" "$unpushed" "$br" "$r"
  done
  for d in "$root"/*; do
    [ -d "$d" ] || continue
    find "$d" -maxdepth 4 -name .git 2>/dev/null | grep -q . || printf 'NOGIT  %6s  %s\n' "$(du -sh "$d" 2>/dev/null | cut -f1)" "$d"
  done
done
