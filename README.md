# Clean Timer

A compact countdown widget for KDE Plasma 6. I made it because I couldn't find a timer that was small enough for my panel, quick to set, and usable from the keyboard. The remaining time stays visible on the panel, so I can check it at a glance. When time runs out, a sound plays.

## USE

Click the widget to open the timer. Type a duration and press **Enter** to start.

### Keyboard (in popup)

| Key | Action |
| --- | --- |
| **Left / Right** | Switch unit |
| **Up / Down** | +/- 1 |
| **Shift + Up / Down** | +/- 5 (+/- 10 for seconds) |
| **Space** | Pause / resume |
| **R** | Reset |
| **Escape** | Close |

### Mouse (on widget)

| Action | Result |
| --- | --- |
| **Scroll** | +/- 1 min (5 min with Shift) |
| **Ctrl + Scroll** | +/- 1 sec (10 sec with Shift) |
| **Middle-click** | Pause / resume |
| **Left-click** | Toggle popup |

## Install

### Option A: Development (Live Symlink)

```sh
git clone https://github.com/<username>/clean-timer.git
cd clean-timer
mkdir -p ~/.local/share/plasma/plasmoids
ln -sfn "$(pwd)" ~/.local/share/plasma/plasmoids/com.eko.cleantimer
./reload.sh
```

> [!WARNING]
> **Never** run `kpackagetool6 --upgrade .` if the applet is installed as a symlink (`ln -s`). `kpackagetool6` follows directory symlinks during package uninstallation/upgrade and will recursively wipe the source repository. When developing with a symlink, always reload via `./reload.sh`.

### Option B: Static Install

To install as an isolated package copy:

```sh
git clone https://github.com/<username>/clean-timer.git
cd clean-timer
kpackagetool6 --type Plasma/Applet --install .
```

---

### Add to Panel

After installing with either option:

1. Right click your panel, and click **Add or Manage Widgets** 
2. Search for **Clean Timer** and add it to wherever you want.

Don't forget to bind the "activate widget" to a global shortcut so you can trigger popup anytime you want. The best way to use it.

## Finish cue

The alert sound is bundled in the repository at `contents/sounds/alarm-clock-elapsed.oga` and played using `pw-play` or `paplay`. You can customize or replace this file with any audio file of your choice. If the bundled file is removed, it automatically falls back to `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`.
