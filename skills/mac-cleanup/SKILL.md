---
name: mac-cleanup
description: Safe, approval-first review and cleanup of a slow or full Mac. Audits disk space, caches, developer junk (node_modules, Xcode, Docker, package caches, old AI-agent worktrees), startup and background items, unused or overlapping apps, stuck print jobs and runaway processes, then reports findings in plain English and cleans up only what the user approves. Use this whenever someone says their Mac or MacBook is slow, laggy, hot, out of space, "storage almost full", wants to free up disk space, asks what is running at startup, wants to declutter, uninstall unused apps, clear caches, or "review my Mac", even if they do not say "cleanup".
---

# Mac cleanup

Help the user get a faster, emptier Mac without losing anything they care about. The job has two halves that must stay separate: a **read-only audit** that finds everything, and a **cleanup** that only touches what the user explicitly approved.

The user is often not technical. Many items on a Mac have cryptic names (`mds_stores`, `colima`, `com.google.keystone.agent`). Part of the value you add is telling them, in one plain sentence each, what a thing is and whether they need it.

## Ground rules

These exist because cleanup mistakes are permanent and the user trusts you with their machine.

- **Audit first, change nothing.** The audit phase is read-only. Do not delete, unload, quit or "quickly tidy" anything until the user has seen the report and said yes.
- **Approval is per category, and it does not carry over.** "Clear caches" is not permission to delete Downloads. If an item is ambiguous (did they mean the app or just its startup item?), ask.
- **Look before you delete.** Before removing a folder, check what is in it. Before removing a git checkout, run `scripts/check-worktrees.sh` so uncommitted or unpushed work is never lost. Keep anything marked KEEP and tell the user why.
- **Prefer the tool's own cleanup command** (`npm cache clean --force`, `brew cleanup`, `docker system prune`, `xcrun simctl delete unavailable`, `uv cache clean`, `pip cache purge`, an app's own uninstaller) over `rm -rf`, because they know what is safe to drop.
- **Measure, do not guess.** Record free space with `df -h /System/Volumes/Data` before you start, after each batch and at the end. Report real numbers. `du` sizes can add up to more than the space actually freed (shared or cloned files), so the `df` difference is the true total. `df` does not count "purgeable" space, so Finder may show a bigger number; mention this if the user compares.
- **Things that look like junk but often are not:** backups (restic, Time Machine, Arq, Carbon Copy, rsync scripts), tunnels and servers (cloudflared, Tailscale, ngrok, sshd), container VMs (Docker, Colima, OrbStack), sync clients (iCloud, Dropbox, Google Drive), password managers, VPNs, hardware toolchains (PlatformIO, Arduino). Explain them and default to keeping them unless the user says otherwise.
- **Never touch** `/System`, `/usr` (except `/usr/local`), anything SIP-protected, other users' home folders, or the contents of `~/Library/Keychains`, `~/Library/Mail` (the mail store itself), `~/Library/Messages`, and the insides of Photos, Music, iMovie, Final Cut or Lightroom libraries and virtual machine bundles.
- **Prefer the Trash for the user's own files.** `trash <path>` (built into macOS 15+) is undoable; `rm -rf` is not. Use `rm` for caches and rebuildable folders, or when the user explicitly chooses permanent deletion.
- **Do not empty the Trash or delete iCloud Drive / cloud-synced files** (`~/Library/Mobile Documents`, `~/Library/CloudStorage`) without asking specifically, since deleting a synced file deletes it everywhere.
- **App data can be the only copy of the user's work.** `~/Library/Application Support/<app>` and `~/Library/Containers/<id>` often hold notes, documents and settings. Ask separately before deleting them, even when uninstalling the app.

## Phase 1: Audit (read-only)

1. Note the starting free space: `df -h /System/Volumes/Data`.
2. Run the bundled audit. It takes a few minutes on a big drive, so run it in the background and write it to a scratch file:
   `bash <skill-dir>/scripts/audit.sh > <scratch>/mac-audit.txt 2>&1`
   Use `--quick` if the user only cares about speed and startup, not space.
3. While it runs, tell the user macOS may show prompts: folder access for Desktop, Documents, Downloads or Photos, and "wants to control System Events" (used only to read login items). Allowing them lets the audit see everything; declining just leaves gaps.
4. Run the two helpers too, if relevant:
   - `bash <skill-dir>/scripts/check-worktrees.sh [folders]` (AI coding agents like Codex, Cursor, Claude Code and Grok leave full repo copies behind). It checks the common agent folders by default; Claude Code keeps worktrees inside each repo at `<repo>/.claude/worktrees`, so pass those too. Only SAFE entries may be removed: KEEP means uncommitted or new files, stashes, or commits that exist nowhere else.
   - `bash <skill-dir>/scripts/stale-node-modules.sh 60` (JavaScript dependency folders in projects untouched for 60 days)
5. Look for build output in projects (`.next`, `.turbo`, `.nuxt`, Rust `target`): these are often bigger than node_modules and always rebuild. See the catalog for the find command.
6. Dig into anything big that the audit cannot explain. `du -sh <folder>/* | sort -rh | head` is the usual next step.

Read `references/catalog.md` when you need to know what an item is, whether it regenerates, and the safest way to clean it. Read `references/startup-items.md` when you deal with login items, launch agents, launch daemons or background items.

### Things to diagnose, not just measure

- **"Slow right now"**: compare the load average to the core count. Common culprits right after boot are Spotlight indexing (`mds_stores`, `mdworker`), Photos analysis (`photoanalysisd`, `mediaanalysisd`), a backup job that runs at login, or cloud sync catching up. These are often temporary; say so.
- **Spotlight** is the built-in macOS search, not an app. It cannot be uninstalled. If it is hogging CPU, the fix is to exclude huge developer folders (System Settings > Spotlight > Search Privacy).
- **Stuck print jobs** show up as a process named after the printer, using memory or CPU. `lpstat -o` lists them; `cancel -a <printer>` clears the user's own jobs.
- **Orphaned startup items**: the audit flags launch agents whose program no longer exists. These are leftovers from apps that were dragged to the Trash.
- **Overlapping apps**: several browsers, several AI chat apps, several editors. Each brings its own updater and background helper. List them and let the user pick what stays.
- **Apps not opened in months**: the audit shows last-used dates. "never" can also mean Spotlight has no record, so treat it as a hint.

## Phase 2: Report

Present a report the user can act on in a minute. Lead with the answer to their actual question (why is it slow, where did the space go). Use this structure:

```
## Why it feels slow
<1-3 bullets: the specific processes or causes, with numbers>

## Disk: <used> used, <free> free
| What | Size | Notes |
<largest items first; one plain-English note each; say what regenerates>

## Startup and background
<grouped: servers/tunnels, updaters, login items, helpers; flag orphans>

## Overlapping or unused apps
<list with sizes and last-used dates>

## My recommendation
**Safe to do now** (nothing lost, things rebuild themselves): ...
**Needs a yes from you, item by item**: numbered list
**Probably keep**: items that look like junk but are not, with one line why
```

Give a rough total of what is reclaimable. Do not pad the report with things that are tiny.

## Phase 3: Ask

Ask the user to choose. If you have a structured question tool, use it for the decisions that are genuinely ambiguous (app vs. startup item only, permanent delete vs. Trash, which of two versions to keep). Answer anything they say "no idea what that is" about before acting on it, and check usage first where you can (for example `colima list`, `docker ps -a`, or searching for project files that use a toolchain). Confirm destructive, irreversible steps like "delete everything in Downloads" once, plainly, naming anything that looks important inside.

## Phase 4: Clean up

Work in batches, user-level first, and record `df` free space after each batch.

1. **User-level** (no password needed): caches, Downloads, old worktrees, stale node_modules, user-owned apps in `/Applications`, their leftovers in `~/Library/{Application Support,Caches,Preferences}`, login items (`osascript -e 'tell application "System Events" to delete login item "<name>"'`), user launch agents (`launchctl bootout gui/$(id -u)/<label>` then remove the plist).
2. **Admin-level** (root-owned apps, `/Library/LaunchDaemons`, `/Library/LaunchAgents`, `/Library/PrivilegedHelperTools`): write the commands into one reviewed script in a scratch folder. Running `sudo` from an agent's shell usually fails because there is no terminal for the password prompt. Instead run it through the macOS password dialog:
   `osascript -e 'do shell script "bash <script>" with administrator privileges with prompt "<what this does>"'`
   Tell the user a password dialog is about to appear. The script runs as root, so `$(id -u)`, `~` and `$HOME` will not point at the user: write their numeric uid (from `id -u` beforehand) and absolute paths into the script.
3. **Quit apps before deleting their data** (check with `pgrep -x` or System Events). Deleting a running app's cache can corrupt it.
4. **Read-only or locked files**: if `rm` reports "Permission denied" on the user's own files, check with `ls -lO`. Run `chmod -R u+w` for read-only folders and `chflags -R nouchg` for locked files, then retry. Only do this inside folders the user already approved for deletion.
5. **Adobe apps**: use Adobe's uninstaller (see `references/catalog.md`) rather than dragging the folder to the Trash, so Creative Cloud does not keep a broken record.
6. After each batch, verify the targets are actually gone (`ls -d` them) and report failures honestly.

Things that need the user's own hands, like Spotlight privacy exclusions, are faster as clear click-by-click instructions than as workarounds.

## Phase 5: Summary

End with a short before/after the user could screenshot:

```
| Area | Before | After | Benefit |
| Free space | 100 GB | 300 GB | +200 GB |
| Startup items | ... | ... | faster boot, less background CPU |
...
```

Then list what you deliberately left alone and why, anything that needs the user (reboot, Spotlight exclusions, uninstallers that need a GUI), and anything worth revisiting later. Suggest a reboot after removing startup items.
