#!/usr/bin/env bash
# READ-ONLY. For every git checkout under a folder, report whether deleting it
# could lose work. Use this before removing any AI-agent worktree or old clone.
#
# Usage: bash check-worktrees.sh [folder ...]
#   Default folders: ~/.codex/worktrees ~/.grok/worktrees ~/.cursor/worktrees ~/.claude/worktrees
#   Claude Code keeps worktrees inside each repo (<repo>/.claude/worktrees): pass those paths too.
#
# Output: VERDICT  size  modified  kind  changes=N  stashes=N  unpushed=N  branch  path
#   SAFE   nothing would be lost: no modified or new files, and every commit exists elsewhere
#          (linked worktree: on a branch kept in the main repo; clone: on the remote)
#   KEEP   something would be lost; show the user before touching it
#   NOGIT  folder with no git checkout inside; look at its contents before deleting
#
# A linked worktree has a .git FILE (its history lives in the main repo).
# A standalone clone has a .git DIRECTORY (deleting it deletes its history).

set -u
[ $# -eq 0 ] && set -- "$HOME/.codex/worktrees" "$HOME/.grok/worktrees" "$HOME/.cursor/worktrees" "$HOME/.claude/worktrees"

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
      [ "$onbr" -eq 0 ] && verdict=KEEP
    fi
    [ "$changes" -gt 0 ] && verdict=KEEP
    printf '%-5s  %6s  %s  %-8s  changes=%s  stashes=%s  unpushed=%s  %s  %s\n' \
      "$verdict" "$(du -sh "$r" 2>/dev/null | cut -f1)" "$(stat -f %Sm -t %F "$r")" "$kind" \
      "$changes" "$stashes" "$unpushed" "$br" "$r"
  done
  for d in "$root"/*; do
    [ -d "$d" ] || continue
    find "$d" -maxdepth 4 -name .git 2>/dev/null | grep -q . || printf 'NOGIT  %6s  %s\n' "$(du -sh "$d" 2>/dev/null | cut -f1)" "$d"
  done
done
