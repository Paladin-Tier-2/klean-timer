# Clean Timer

A compact countdown widget for KDE Plasma 6. I made it because I couldn't find a timer that was small enough for my panel, quick to set, and usable from the keyboard. The remaining time stays visible on the panel, so I can check it at a glance. When time runs out, a sound plays.

## Use it

Click the widget to open the timer. Type a duration and press **Enter** to start.

| Control | Action |
| --- | --- |
| **Left / Right** | Select minutes or seconds |
| **Up / Down** | Add or subtract 1 minute or 1 second, depending on the selection |
| **Shift + Up / Down** | Add or subtract 5 minutes or 10 seconds |
| **Space** | Pause or resume a running timer |
| **R** | Reset |
| **Escape** | Close the popup |
| **Mouse wheel** | Adjust the selected unit |
| **Middle-click on the panel widget** | Pause or resume |

You can also adjust minutes with the buttons in the popup. While a timer is running, the panel widget shows the countdown instead of its icon.

## Install

### Development (Live Symlink)

Link the repository into your Plasma applets directory so edits take effect immediately:

```sh
mkdir -p ~/.local/share/plasma/plasmoids
ln -sfn "$(pwd)" ~/.local/share/plasma/plasmoids/com.eko.cleantimer
./reload.sh
```

Then add **Clean Timer** to a Plasma panel from **Edit Mode → Add Widgets**.

### Static Install

To install as an isolated package copy:

```sh
kpackagetool6 --type Plasma/Applet --install .
```

> [!WARNING]
> **Never** run `kpackagetool6 --upgrade .` if the applet is installed as a symlink (`ln -s`). `kpackagetool6` follows directory symlinks during package uninstallation/upgrade and will recursively wipe the source repository. When developing with a symlink, always reload via `./reload.sh`.

## Finish cue

The alert sound is bundled in the repository at `contents/sounds/alarm-clock-elapsed.oga` and played using `pw-play` or `paplay`. You can customize or replace this file with any audio file of your choice. If the bundled file is removed, it automatically falls back to `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`.
