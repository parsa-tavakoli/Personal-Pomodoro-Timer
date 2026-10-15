# Pomodoro

A calm focus timer for your Mac. Work in pomodoros, take breaks, and see where your time goes.

<p align="center"><img src="Resources/logo.png" width="160" alt="Pomodoro app icon"></p>

- **Focus sessions:** a fixed number of pomodoros, or a flexible session that grows one pomodoro at a time
- **Overtime:** in flexible mode, the timer keeps counting past zero until you choose a short break, a long break, or to stop
- **Name what you're working on:** sessions are grouped by name in your stats
- **History and Stats:** a week view, a daily chart with a goal line, your most focused hours, and time per task
- **Menu bar timer:** the time is always visible at the top of your screen
- **Notifications** when a timer finishes

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

## Uninstall

Drag **Pomodoro** from Applications to the Trash. To also delete your history, remove the folder `~/Library/Application Support/Pomodoro` (in Finder: **Go → Go to Folder…** and paste that path).

---

## For developers

### Build from source

You need the Xcode Command Line Tools (`xcode-select --install`) with the macOS 26 SDK.

```bash
./scripts/bundle.sh          # builds a universal Pomodoro.app
open Pomodoro.app
./scripts/make_dmg.sh        # packs it into dist/Pomodoro-<version>.dmg
```

### Publish a release

Push a version tag. GitHub Actions ([release.yml](.github/workflows/release.yml)) builds the `.dmg` and publishes a GitHub Release with it:

```bash
git tag v1.0.0
git push origin v1.0.0
```

To try the build without publishing, run the **Release** workflow by hand from the *Actions* tab; the `.dmg` appears under the run's *Artifacts*.

The app is currently ad-hoc signed, which is why users see the one-time "Open Anyway" step. With an Apple Developer account, the commented-out signing and notarization steps in `release.yml` remove that step.
