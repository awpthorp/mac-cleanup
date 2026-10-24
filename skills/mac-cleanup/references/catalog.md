# Cleanup catalog

What common space hogs are, whether they come back on their own, and the safest way to clean them. "Regenerates" means deleting it loses nothing permanent; the app or tool rebuilds it when needed (sometimes with a one-time slowdown or re-download).

## Contents
- [User files](#user-files)
- [Caches](#caches)
- [Developer: JavaScript and Python](#developer-javascript-and-python)
- [Developer: Apple, containers, other toolchains](#developer-apple-containers-other-toolchains)
- [AI coding tools](#ai-coding-tools)
- [Apps and app data](#apps-and-app-data)
- [Games and media](#games-and-media)
- [System-managed space](#system-managed-space)

## User files

| Item | Path | Regenerates | How to clean | Notes |
|---|---|---|---|---|
| Downloads | `~/Downloads` | No | Ask. Default to the Trash so it can be undone: `trash ~/Downloads/*` (macOS 15+ ships `/usr/bin/trash`). Use `rm -rf` only if the user chooses permanent deletion. | Often full of zips sitting next to their already-extracted folders, duplicate `name (1).ext` files and old installers (`.dmg`, `.pkg`). Point those out. |
| Trash | `~/.Trash` | No | Ask; Finder > Empty Trash | The shell may get "Operation not permitted" here without Full Disk Access. That is fine; let the user empty it. |
| Large old files | anywhere in home | No | Ask, per file; prefer `trash` | The audit lists files over 1 GB untouched for 90 days. Videos and disk images are the usual finds. |
| iPhone/iPad backups | `~/Library/Application Support/MobileSync/Backup` | No | Finder > device > Manage Backups, or `trash` a folder after checking its date | Each backup can be 10-100 GB. Keep the newest one unless the user backs up to iCloud. |
| Mail attachments cache | `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads` | Yes | `rm -rf` its contents | Only the opened-attachment copies, not the mail store. |

## Caches

| Item | Path | Regenerates | How to clean |
|---|---|---|---|
| App caches (general) | `~/Library/Caches/<app>` | Yes | Quit the app, then delete its folder. Don't delete `~/Library/Caches` itself. |
| Chrome / Edge / Brave | `~/Library/Caches/Google/Chrome`, etc. | Yes | Quit the browser first. Doesn't log the user out (logins live in Application Support). |
| Spotify | `~/Library/Caches/com.spotify.client` | Yes | Quit Spotify. Offline downloads will re-download. Spotify > Settings > Storage can cap it. |
| Slack, Discord, Teams, Zoom | `~/Library/Application Support/<app>/Cache`, `Service Worker/CacheStorage` | Yes | Quit the app; delete only `Cache`, `Code Cache`, `GPUCache`, `Service Worker/CacheStorage`. |
| Updater leftovers | `~/Library/Caches/*.ShipIt`, `*-updater` | Yes | Delete. These are downloaded update packages. |
| Homebrew | `brew --cache` | Yes | `brew cleanup --prune=all` (also removes old versions of formulas) |
| Logs | `~/Library/Logs` | Yes | Delete files older than ~30 days. Check first for logs the user's own scripts write. |

## Developer: JavaScript and Python

| Item | Path | Regenerates | How to clean |
|---|---|---|---|
| node_modules | inside each project | Yes, via `npm install` | `scripts/stale-node-modules.sh 60` lists ones in idle projects; delete those. Leave active projects alone. |
| Build output | `.next`, `.turbo`, `.nuxt`, `.svelte-kit`, `.parcel-cache`, `dist`, `build`, `target` (Rust) inside projects | Yes, on next build or dev run | Find them: `find ~ -xdev -maxdepth 7 -type d \( -name .next -o -name .turbo -o -name .nuxt \) -prune -not -path "*/node_modules/*" 2>/dev/null`. Safe to delete for any project not currently running a dev server. Check `dist`/`build` are not committed or published artifacts first. |
| npm cache | `~/.npm` | Yes | `npm cache clean --force` |
| pnpm store | `~/Library/pnpm/store` | Yes | `pnpm store prune` |
| Yarn cache | `~/Library/Caches/Yarn`, `~/.yarn/berry/cache` | Yes | `yarn cache clean` |
| Bun cache | `~/.bun/install/cache` | Yes | `bun pm cache rm` |
| Old Node versions | `~/.nvm/versions/node/*` | Reinstallable | `nvm ls`, then `nvm uninstall <old>`; keep the default and any a project pins. |
| uv | `~/.cache/uv` | Yes | `uv cache clean` |
| pip | `~/Library/Caches/pip`, `~/.cache/pip` | Yes | `pip3 cache purge` |
| Conda packages | `~/miniconda3/pkgs`, `~/anaconda3/pkgs` | Yes | `conda clean --all` |
| Python virtualenvs | `.venv` in idle projects | Yes, from requirements | Ask; same idea as node_modules. Don't delete a venv a launch agent runs from (check `ProgramArguments`). |
| Browser test binaries | `~/Library/Caches/ms-playwright*`, `~/.cache/puppeteer` | Yes | Delete. Re-downloaded on next test run. |
| Hugging Face models | `~/.cache/huggingface` | Re-downloadable | Ask; can be very large and slow to re-download. |

## Developer: Apple, containers, other toolchains

| Item | Path | Regenerates | How to clean |
|---|---|---|---|
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Yes | Delete. Next build is slower once. |
| Xcode Archives | `~/Library/Developer/Xcode/Archives` | No | Ask: these are shipped builds and needed to symbolicate old crash reports. |
| iOS DeviceSupport | `~/Library/Developer/Xcode/iOS DeviceSupport` | Yes | Delete versions for iOS releases no device uses any more. |
| Simulators | `~/Library/Developer/CoreSimulator` | Partly | `xcrun simctl delete unavailable`; for runtimes, Xcode > Settings > Platforms. |
| Docker Desktop | `~/Library/Containers/com.docker.docker` | Images re-pullable | `docker system prune -a` (ask: removes stopped containers and unused images). Volumes may hold databases: `docker volume ls` first. |
| Colima / Lima / OrbStack | `~/.colima`, `~/.lima`, `~/.orbstack` | VM disk | `colima list` shows profiles; ask before `colima delete <profile>`. A stopped VM costs disk, not speed. |
| Rust | `~/.cargo/registry`, `~/.rustup/toolchains` | Yes | `cargo cache -a` if installed; `rustup toolchain list` and remove old ones. |
| Go | `~/go/pkg/mod` | Yes | `go clean -modcache` |
| Gradle / Maven | `~/.gradle/caches`, `~/.m2/repository` | Yes | Delete the caches folder. |
| CocoaPods | `~/Library/Caches/CocoaPods` | Yes | `pod cache clean --all` |
| PlatformIO / Arduino | `~/.platformio`, `~/Library/Arduino15` | Re-downloadable | Ask; search for `platformio.ini` / `.ino` projects first. Needed to flash hardware. |
| Ollama / LM Studio models | `~/.ollama/models`, `~/.lmstudio` | Re-downloadable | `ollama list` then `ollama rm <model>`. Ask; large and slow to re-download. |

## AI coding tools

These tools create full copies of repositories ("worktrees") for each task and rarely clean them up. Each copy can include its own `node_modules` and build output, so they add up fast.

| Item | Path | How to clean |
|---|---|---|
| Codex worktrees | `~/.codex/worktrees` | Run `scripts/check-worktrees.sh`. For SAFE linked worktrees: find the main repo with `git -C <path> rev-parse --git-common-dir`, then `git -C <main repo> worktree remove <path>` (no `--force`: if git refuses, something would be lost, so stop and show the user). Then `git -C <main repo> worktree prune`. Keep KEEP entries and tell the user why. |
| Grok / Cursor / Claude worktrees | `~/.grok/worktrees`, `~/.cursor/worktrees`, `<repo>/.claude/worktrees` | Same as above; pass the folders to `check-worktrees.sh`. Standalone clones (`kind=clone`) are only SAFE if every commit is on the remote. NOGIT folders are plain copies: look inside and ask before deleting. |
| Agent session logs | `~/.codex/sessions`, `~/.grok/sessions` | Old conversation history. Ask; usually safe to trim old months. |
| Cursor agent cache | `~/Library/Application Support/Cursor/User/globalStorage/anysphere.cursor-agent-worker` | Quit Cursor, delete. Leave `state.vscdb` (settings and chat history). |
| VS Code / Cursor extension downloads | `.../CachedExtensionVSIXs`, `CachedData` | Delete. |
| Claude desktop VM image | `~/Library/Application Support/Claude/vm_bundles` | Sandbox used by the Claude desktop app's agent features. Deleting it means a large re-download on next use; leave it if they use the app. |

## Apps and app data

- **Uninstalling an app**: quit it, delete `/Applications/<App>.app`, then the leftovers. Find leftovers by its bundle id: `defaults read "/Applications/<App>.app/Contents/Info" CFBundleIdentifier`, then look for that id and the app name in `~/Library/Caches`, `~/Library/Preferences/<id>.plist`, `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons`, `/Library/PrivilegedHelperTools` (safe to remove once the app is gone).
- **App data is user data**: `~/Library/Application Support/<app>` and `~/Library/Containers/<id>` can hold the only copy of the user's notes, documents or settings (note-taking apps, task managers, journals keep everything there). Say what is inside and how big it is, and get a separate yes before deleting. Remove `~/Library/Group Containers/<team>.<name>` only if no other app from the same vendor is still installed: these are shared (for example one Office group container serves every Office app).
- **Bundle ids don't always match the name** (rebranded apps keep old ids). Check the id rather than guessing from the name.
- **Root-owned apps** (installed via `.pkg`) need admin rights; see Phase 4 in SKILL.md.
- **Adobe**: `"/Library/Application Support/Adobe/Adobe Desktop Common/HDBox/Setup" --uninstall=1 --sapCode=<CODE> --baseVersion=<MAJOR.0> --platform=<PLATFORM> --deleteUserPreferences=false` (run as admin). `<PLATFORM>` is `macarm64` for a native Apple Silicon install and `osx10-64` for Intel; check with `lipo -archs "<App>.app/Contents/MacOS/<binary>"`. If it fails, uninstall from the Creative Cloud app instead. Codes: ILST Illustrator, PHSP Photoshop, IDSN InDesign, PPRO Premiere Pro, AEFT After Effects, AUDT Audition, LTRM Lightroom Classic. Get the major version from the app's `CFBundleShortVersionString`. Or use the Creative Cloud app.
- **Microsoft leftovers**: if no Microsoft apps remain (check for Word, Excel, PowerPoint, Outlook, OneNote, Teams, Edge, Defender, Windows App, OneDrive), `com.microsoft.autoupdate*`, `com.microsoft.office.licensingV2.helper`, `com.microsoft.OneDrive*Updater*` and `com.microsoft.SyncReporter` can all go. If any Microsoft app remains, keep AutoUpdate; keep licensing while any Office app remains.
- **Old versions side by side** (for example two years of Photoshop): ask which to keep.
- **Printer apps**: the vendor app (HP Smart, Canon, Epson) is rarely needed to print; macOS AirPrint drivers handle most printers. Removing the app doesn't remove the printer.

## Games and media

| Item | How to clean | Notes |
|---|---|---|
| Steam games | Steam > Library > right-click > Uninstall, or delete `steamapps/common/<dir>` plus its `appmanifest_<id>.acf` and `workshop/content/<id>` with Steam quit | The audit shows last-played dates. Save games are usually in the cloud or `~/Library/Application Support/<game>`, which uninstalling doesn't remove. |
| Epic, GOG, Battle.net | Use the launcher's uninstall | |
| GarageBand / Logic sound libraries | GarageBand > Sound Library, or delete `/Library/Application Support/GarageBand` | Several GB, re-downloadable. Shared with Logic Pro: ask first if Logic is installed. |
| iMovie, GarageBand, Keynote, Pages, Numbers | Delete from `/Applications` | Free from the App Store if needed later. |
| Photos library | Don't delete inside it | Suggest "Optimize Mac Storage" in Photos settings if iCloud Photos is on. |

## System-managed space

- **APFS local snapshots** (`tmutil listlocalsnapshots /`): Time Machine and macOS updates keep these. macOS frees them automatically under disk pressure. Time Machine ones are local backups, so ask first; `tmutil thinlocalsnapshots / 999999999999 4` then asks macOS to free space now. Don't delete `com.apple.os.update-*` snapshots manually.
- **"System Data" in Storage settings** is mostly caches, logs, snapshots, VM swap and Time Machine staging. The items above are usually what makes it large.
- **Swap and sleep image** (`/private/var/vm`): managed by macOS; don't touch.
