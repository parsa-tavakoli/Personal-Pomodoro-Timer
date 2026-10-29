# Pomodoro

A calm focus timer for your Mac. Work in pomodoros, take breaks, and see where your time goes.

<p align="center"><img src="Resources/logo.png" width="160" alt="Pomodoro app icon"></p>

## Features

- **Two kinds of session:** a *fixed* number of pomodoros with automatic breaks, or a *flexible* session that grows one pomodoro at a time.
- **Overtime:** in flexible mode, a finished timer keeps counting (+00:42…) until you choose a short break, a long break, or to stop.
- **Name what you're working on:** your stats are grouped by these names (your *tasks*).
- **Projects:** group sessions into projects such as "Thesis" or "Work", each in one of 10 colours. Pick one from the dot in "What are you working on?". The colours appear in the timeline, the session list and Stats.
- **Archive or delete:** in **Settings → Projects & Tasks**, or by right-clicking a row in Stats.
  - Archiving hides a project or task but keeps its history.
  - Deleting a project keeps its sessions (as "No project").
  - Deleting a task removes its sessions.
- **History:**
  - a week strip, with **‹ ›** to browse older weeks;
  - a **day timeline** showing your focus blocks hour by hour, with breaks as gaps;
  - a list of the day's sessions, where you can rename them or change their project.
- **Stats** for a **Day** (with ‹ › to go back through earlier days), the **Week** (Monday to Sunday) or the last 30 days:
  - focus time, sessions and your streak;
  - pomodoros per day, with a daily goal line (Week and Month);
  - your most focused hours, across all 24 hours;
  - time per project and per task. Click one to filter the whole page.
- **Menu bar timer:** just the time, always visible at the top of your screen.
- **Notifications** when a timer finishes. Only the latest one is kept, so they don't pile up.
- **Update notice:** Pomodoro tells you when a new version is out.
- **Dark design** with Liquid Glass controls.

## Requirements

- macOS 26 Tahoe or later
- Any Mac (Apple Silicon or Intel)

## Install

1. **[Download the latest version](https://github.com/parsa-tavakoli/Personal-Pomodoro-Timer/releases/latest)**: under *Assets*, click the file named `Pomodoro-….dmg`.
2. Open the downloaded file. In the window that appears, **drag Pomodoro onto the Applications folder**.
3. Open **Applications** and double-click **Pomodoro**.

### The first time you open it

Pomodoro is a free app that isn't registered with Apple yet, so the first time you open it macOS will say:

> **"Pomodoro" Not Opened**: Apple could not verify "Pomodoro" is free of malware…

This only happens once. To allow it:

1. Click **Done** (not *Move to Trash*).
2. Open **System Settings** (the gear icon in the Dock, or  menu → System Settings).
3. Click **Privacy & Security** in the sidebar.
4. Scroll down to the **Security** section. You'll see *"Pomodoro" was blocked to protect your Mac.* Click **Open Anyway**.
5. Click **Open Anyway** again in the box that appears, and enter your Mac password (or use Touch ID).

Pomodoro opens. From now on it opens normally, like any other app.

When Pomodoro asks to send notifications, click **Allow**, so it can tell you when a timer finishes.

## Update

When a new version is out, Pomodoro shows **"Version … is available · Download"** at the top of the Timer page (and in the menu bar menu). To update:

1. Finish or end any running session, then quit Pomodoro (click the time in the menu bar → **Quit**).
2. Click **Download** (or get the newest `.dmg` from the [Releases page](https://github.com/parsa-tavakoli/Personal-Pomodoro-Timer/releases/latest)) and open it.
3. Drag Pomodoro onto Applications and choose **Replace**.
4. Open it. As with the first install, macOS asks once more, so use **Open Anyway** again.

Your history, projects and settings aren't stored inside the app, so they carry over to the new version.

*Versions before 1.0.4 don't have the update notice. If you're on one of those, download the latest version once by hand.*

## Privacy

Everything stays on your Mac. The only time Pomodoro goes online is to check this page for a newer version (once at launch and once a day); it sends nothing about you or your sessions.

## Uninstall

Drag **Pomodoro** from Applications to the Trash. To also delete your history and projects, remove the folder `~/Library/Application Support/Pomodoro` (in Finder: **Go → Go to Folder…** and paste that path).

---

## For developers

### Build from source

You need the Xcode Command Line Tools (`xcode-select --install`) with the macOS 26 SDK.

```bash
./scripts/bundle.sh          # builds a universal Pomodoro.app (Apple Silicon + Intel)
open Pomodoro.app
./scripts/make_dmg.sh        # packs it into dist/Pomodoro-<version>.dmg
```

The version number comes from the latest git tag (for example `v1.0.4` gives `1.0.4`). To override it, use `VERSION=1.2.0 ./scripts/bundle.sh`. App icon: `swift scripts/make_icon.swift --full-bleed Resources/logo.png Resources/AppIcon.icns`.

The code lives in `Sources/Pomodoro`:
- `SessionTimer.swift`: the timer engine and focus-block log;
- `HistoryStore.swift` / `ProjectStore.swift`: saved sessions, projects and archived tasks;
- `Stats.swift`: the numbers behind the Stats page;
- `ArchiveActions.swift`: the confirmed delete actions;
- `UpdateChecker.swift`: the release check;
- `Theme.swift`: colours, fonts and spacing;
- `Views/`: the screens.

### Publish a release

Push a version tag. GitHub Actions ([release.yml](.github/workflows/release.yml)) builds the `.dmg` and publishes a GitHub Release with it:

```bash
git tag v1.0.7
git push origin v1.0.7
```

Everyone on 1.0.4 or later then sees the update notice within a day.

To try the build without publishing, run the **Release** workflow by hand from the *Actions* tab; the `.dmg` appears under the run's *Artifacts*.

The app is currently ad-hoc signed, which is why users see the one-time "Open Anyway" step. With an Apple Developer account, the commented-out signing and notarization steps in `release.yml` remove that step.

## License

Pomodoro is free software under the [MIT License](LICENSE).
The bundled fonts (Space Grotesk, IBM Plex Sans, JetBrains Mono) are under the [SIL Open Font License](Resources/Fonts/licenses).
