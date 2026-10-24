# Startup and background items

macOS starts third-party software in several ways. They all show up together in System Settings > General > Login Items & Extensions, which is a good place to send the user if they would rather click than type.

| Kind | Where | Runs as | Remove with |
|---|---|---|---|
| Login items | System Events list | the user, at login | `osascript -e 'tell application "System Events" to delete login item "<Name>"'` |
| User launch agents | `~/Library/LaunchAgents/*.plist` | the user | `launchctl bootout gui/$(id -u)/<label>`, then delete the plist |
| System launch agents | `/Library/LaunchAgents/*.plist` | each user (needs admin to remove) | admin: `launchctl bootout gui/<uid>/<label>`, delete plist |
| Launch daemons | `/Library/LaunchDaemons/*.plist` | root, at boot | admin: `launchctl bootout system/<label>`, delete plist |
| Privileged helpers | `/Library/PrivilegedHelperTools/*` | root, on demand | admin: delete after its daemon plist is gone |
| App-embedded background items | inside an app bundle (`Contents/Library/LoginItems`) | the user | Toggle off in System Settings, or uninstall the app |

`<label>` is the plist's `Label` key, usually the file name without `.plist`.

## Reading a plist quickly

```bash
/usr/libexec/PlistBuddy -c 'Print' <file.plist>
```

What matters:
- `ProgramArguments` / `Program`: what it runs. If that path no longer exists, it is probably an orphan from an app that was dragged to the Trash. Before removing it, check the path is not on an external drive that is unplugged, and that it is not a `BundleProgram` (relative to an app bundle).
- `RunAtLoad`: starts at login or boot.
- `KeepAlive`: restarts if it exits. Something with KeepAlive that is crashing will burn CPU in a loop; check its log paths.
- `StartCalendarInterval` / `StartInterval`: scheduled job.
- `WatchPaths`: runs when a file changes.

## Triage guide

| Usually safe to remove | Ask first | Usually keep |
|---|---|---|
| Updaters for apps that are no longer installed | Updaters for apps that are installed: the app stops auto-updating (Google Keystone/GoogleUpdater, Microsoft AutoUpdate, Zoom updater, Adobe ARMDC) | The user's own scripts (backups, sync, monitors): read the script and explain it |
| Orphaned agents whose program is missing | Servers: FTP/SFTP servers, web servers, databases at boot (often installed once and forgotten; also an open door) | Tunnels/VPNs they rely on (cloudflared, Tailscale, WireGuard) |
| Login items for apps the user doesn't want auto-starting | Sync clients (Dropbox, Google Drive, OneDrive): removing stops sync | Security and password tools |
| Duplicate updaters (an old and new updater from the same vendor) | Vendor helpers for hardware (printer, mouse, audio interface) | Helpers an installed app needs to function (for example a meeting app's audio driver daemon) |

## User's own scheduled jobs

If a custom script (for example a backup) is hogging CPU at login because of `RunAtLoad`, don't remove it. Read the script first. Many already skip work if the last run was recent. Options to suggest:
- keep `RunAtLoad` but add or raise `Nice` and set `LowPriorityIO` and `ProcessType` = `Background`
- rely on `StartCalendarInterval` only (launchd runs a missed calendar job when the Mac wakes, but not one missed while it was powered off)

After editing a plist: `launchctl bootout gui/$(id -u)/<label>; launchctl bootstrap gui/$(id -u) <plist>`.
