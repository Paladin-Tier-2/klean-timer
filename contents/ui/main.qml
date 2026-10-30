import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property int totalSeconds: (plasmoid.configuration.lastSeconds !== undefined && plasmoid.configuration.lastSeconds >= 0) ? plasmoid.configuration.lastSeconds : 300
    property real targetEndTime: plasmoid.configuration.runningEndTime > 0 ? plasmoid.configuration.runningEndTime : 0
    property int remainingSeconds: plasmoid.configuration.pausedSeconds > 0
        ? plasmoid.configuration.pausedSeconds
        : (root.targetEndTime > 0 ? Math.max(0, Math.ceil((root.targetEndTime - Date.now()) / 1000)) : 0)
    property bool isRunning: root.targetEndTime > 0 || plasmoid.configuration.pausedSeconds > 0
    property bool isPaused: plasmoid.configuration.pausedSeconds > 0
    property string adjustUnit: "minutes"
    property string digitBuffer: ""
    property var inputItem: null
    property var compactItem: null

    toolTipMainText: root.isRunning ? i18n("%1 remaining", root.formatTime(root.remainingSeconds)) : i18n("Clean Timer")
    toolTipSubText: {
        if (root.isRunning) {
            return root.isPaused ? i18n("Paused — Middle-click or Space to resume") : i18n("Running — Middle-click or Space to pause\nScroll or Up/Down to adjust");
        }
        return i18n("Click to set timer\nScroll or Up/Down to adjust time");
    }

    function resolveSoundPath() {
        var localUrl = Qt.resolvedUrl("../sounds/alarm-clock-elapsed.oga").toString();
        if (localUrl.startsWith("file://")) {
            return decodeURIComponent(localUrl.substring(7));
        }
        return "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";
    }

    function formatTime(sec) {
        sec = Math.max(0, parseInt(sec) || 0);
        var h = Math.floor(sec / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var s = sec % 60;
        var pad = function(n) { return n < 10 ? "0" + n : "" + n; };
        if (h > 0) {
            return pad(h) + ":" + pad(m) + ":" + pad(s);
        }
        return pad(m) + ":" + pad(s);
    }

    function parseTimeInput(str) {
        str = ("" + str).trim().toLowerCase();
        if (!str) return 0;

        if (str.includes(":")) {
            var parts = str.split(":");
            if (parts.length === 2) {
                if (!/^\d*$/.test(parts[0]) || !/^\d*$/.test(parts[1])) return -1;
                var m = parseInt(parts[0]) || 0;
                var s = parseInt(parts[1]) || 0;
                s = Math.min(59, Math.max(0, s));
                m = Math.max(0, m);
                return Math.min(86400, (m * 60) + s);
            } else if (parts.length === 3) {
                if (!/^\d*$/.test(parts[0]) || !/^\d*$/.test(parts[1]) || !/^\d*$/.test(parts[2])) return -1;
                var h = parseInt(parts[0]) || 0;
                var m = parseInt(parts[1]) || 0;
                var s = parseInt(parts[2]) || 0;
                s = Math.min(59, Math.max(0, s));
                m = Math.min(59, Math.max(0, m));
                h = Math.max(0, h);
                return Math.min(86400, (h * 3600) + (m * 60) + s);
            }
            return -1;
        }

        var total = 0;
        var matched = false;
        var hMatch = str.match(/(\d+)\s*h/);
        if (hMatch) { total += parseInt(hMatch[1]) * 3600; matched = true; }
        var mMatch = str.match(/(\d+)\s*m/);
        if (mMatch) { total += parseInt(mMatch[1]) * 60; matched = true; }
        var sMatch = str.match(/(\d+)\s*s/);
        if (sMatch) { total += parseInt(sMatch[1]); matched = true; }

        if (matched) {
            var stripped = str.replace(/\d+\s*h/g, "").replace(/\d+\s*m/g, "").replace(/\d+\s*s/g, "").trim();
            if (stripped.length > 0) return -1;
            return Math.min(86400, total);
        }

        if (/^\d+$/.test(str)) {
            var num = parseInt(str);
            if (!isNaN(num) && num >= 0) {
                return Math.min(86400, num * 60);
            }
        }
        return -1;
    }

    function startTimer(seconds) {
        if (seconds > 0) {
            root.totalSeconds = Math.min(86400, seconds);
            plasmoid.configuration.lastSeconds = root.totalSeconds;
            root.remainingSeconds = root.totalSeconds;
            root.targetEndTime = Date.now() + (root.totalSeconds * 1000);
            plasmoid.configuration.pausedSeconds = 0;
            plasmoid.configuration.runningEndTime = root.targetEndTime;
            root.isRunning = true;
            root.isPaused = false;
        }
    }

    function togglePause() {
        if (root.isRunning) {
            if (!root.isPaused) {
                var diff = Math.max(0, Math.ceil((root.targetEndTime - Date.now()) / 1000));
                if (diff === 0) {
                    root.remainingSeconds = 0;
                    root.isRunning = false;
                    root.isPaused = false;
                    root.targetEndTime = 0;
                    plasmoid.configuration.runningEndTime = 0;
                    plasmoid.configuration.pausedSeconds = 0;
                    root.onTimerFinished();
                    return;
                }
                root.remainingSeconds = diff;
                root.isPaused = true;
                plasmoid.configuration.pausedSeconds = diff;
                root.targetEndTime = 0;
                plasmoid.configuration.runningEndTime = 0;
                root.focusInput();
            } else {
                root.targetEndTime = Date.now() + (root.remainingSeconds * 1000);
                root.isPaused = false;
                plasmoid.configuration.runningEndTime = root.targetEndTime;
                plasmoid.configuration.pausedSeconds = 0;
            }
        } else if (root.remainingSeconds > 0) {
            root.targetEndTime = Date.now() + (root.remainingSeconds * 1000);
            root.isRunning = true;
            root.isPaused = false;
            plasmoid.configuration.runningEndTime = root.targetEndTime;
            plasmoid.configuration.pausedSeconds = 0;
        } else {
            startTimer(root.totalSeconds);
        }
    }

    function resetTimer() {
        root.digitBuffer = "";
        if (!root.isRunning && root.remainingSeconds === 0) {
            root.totalSeconds = 0;
            plasmoid.configuration.lastSeconds = 0;
        } else {
            root.isRunning = false;
            root.isPaused = false;
            root.remainingSeconds = 0;
            root.targetEndTime = 0;
            plasmoid.configuration.runningEndTime = 0;
            plasmoid.configuration.pausedSeconds = 0;
        }
        root.focusInput();
    }

    function adjustTime(stepDirection, isShift) {
        root.digitBuffer = "";
        if (!root.isRunning && root.inputItem && root.inputItem.visible) {
            var pendingSeconds = root.parseTimeInput(root.inputItem.text);
            if (pendingSeconds >= 0) {
                root.totalSeconds = pendingSeconds;
                plasmoid.configuration.lastSeconds = pendingSeconds;
            }
        }

        var delta = 0;
        if (root.adjustUnit === "hours") {
            delta = (isShift ? 5 : 1) * 3600;
        } else if (root.adjustUnit === "minutes") {
            delta = (isShift ? 5 : 1) * 60;
        } else {
            delta = (isShift ? 10 : 1);
        }
        var totalChange = stepDirection * delta;

        if (root.isRunning) {
            root.remainingSeconds = Math.min(86400, Math.max(1, root.remainingSeconds + totalChange));
            if (!root.isPaused) {
                root.targetEndTime = Date.now() + (root.remainingSeconds * 1000);
                plasmoid.configuration.runningEndTime = root.targetEndTime;
            } else {
                plasmoid.configuration.pausedSeconds = root.remainingSeconds;
            }
            if (root.isPaused && root.inputItem) {
                root.inputItem.text = root.formatTime(root.remainingSeconds);
                root.selectActiveUnit();
            }
        } else {
            root.totalSeconds = Math.min(86400, Math.max(0, root.totalSeconds + totalChange));
            plasmoid.configuration.lastSeconds = root.totalSeconds;
            if (root.inputItem) {
                root.inputItem.text = root.formatTime(root.totalSeconds);
                root.selectActiveUnit();
            }
        }
    }

    function clearCurrentUnit() {
        root.digitBuffer = "";
        var sec = (root.isRunning && root.isPaused) ? root.remainingSeconds : root.totalSeconds;
        var h = Math.floor(sec / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var s = sec % 60;
        if (root.adjustUnit === "hours") {
            h = 0;
            root.adjustUnit = "minutes";
        } else if (root.adjustUnit === "minutes") {
            m = 0;
        } else {
            s = 0;
        }
        var nextSec = (h * 3600) + (m * 60) + s;
        if (root.isRunning && root.isPaused) {
            root.remainingSeconds = Math.max(1, nextSec);
            plasmoid.configuration.pausedSeconds = root.remainingSeconds;
            if (root.inputItem) {
                root.inputItem.text = root.formatTime(root.remainingSeconds);
                root.selectActiveUnit();
            }
        } else {
            root.totalSeconds = nextSec;
            plasmoid.configuration.lastSeconds = root.totalSeconds;
            if (root.inputItem) {
                root.inputItem.text = root.formatTime(root.totalSeconds);
                root.selectActiveUnit();
            }
        }
    }

    function applyDigit(d) {
        var sec = (root.isRunning && root.isPaused) ? root.remainingSeconds : root.totalSeconds;
        var h = Math.floor(sec / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var s = sec % 60;

        if (root.digitBuffer.length === 0) {
            root.digitBuffer = d;
            var val = parseInt(d);
            if (root.adjustUnit === "hours") h = val;
            else if (root.adjustUnit === "minutes") m = val;
            else s = val;
        } else {
            var val2 = parseInt(root.digitBuffer + d);
            root.digitBuffer = "";
            if (root.adjustUnit === "hours") h = Math.min(23, val2);
            else if (root.adjustUnit === "minutes") m = Math.min(59, val2);
            else s = Math.min(59, val2);
        }
        var nextSec = (h * 3600) + (m * 60) + s;
        if (root.isRunning && root.isPaused) {
            root.remainingSeconds = Math.max(1, nextSec);
            plasmoid.configuration.pausedSeconds = root.remainingSeconds;
            if (root.inputItem) {
                root.inputItem.text = root.formatTime(root.remainingSeconds);
                root.selectActiveUnit();
            }
        } else {
            root.totalSeconds = nextSec;
            plasmoid.configuration.lastSeconds = root.totalSeconds;
            if (root.inputItem) {
                root.inputItem.text = root.formatTime(root.totalSeconds);
                root.selectActiveUnit();
            }
        }
    }

    function adjustMinutes(stepDirection, isShift) {
        var oldUnit = root.adjustUnit;
        root.adjustUnit = "minutes";
        root.adjustTime(stepDirection, isShift);
        root.adjustUnit = oldUnit;
    }

    function selectPreviousUnit() {
        root.digitBuffer = "";
        var sec = (root.isRunning && root.isPaused) ? root.remainingSeconds : root.totalSeconds;
        var str = root.inputItem ? root.inputItem.text : root.formatTime(sec);
        var parts = str.split(":");
        if (parts.length === 3) {
            if (root.adjustUnit === "seconds") {
                root.adjustUnit = "minutes";
            } else if (root.adjustUnit === "minutes") {
                root.adjustUnit = "hours";
            }
        } else {
            root.adjustUnit = "minutes";
        }
        root.selectActiveUnit();
    }

    function selectNextUnit() {
        root.digitBuffer = "";
        var sec = (root.isRunning && root.isPaused) ? root.remainingSeconds : root.totalSeconds;
        var str = root.inputItem ? root.inputItem.text : root.formatTime(sec);
        var parts = str.split(":");
        if (parts.length === 3) {
            if (root.adjustUnit === "hours") {
                root.adjustUnit = "minutes";
            } else if (root.adjustUnit === "minutes") {
                root.adjustUnit = "seconds";
            }
        } else {
            root.adjustUnit = "seconds";
        }
        root.selectActiveUnit();
    }

    function selectActiveUnit() {
        if (!root.inputItem || !root.inputItem.visible) return;
        if (!root.inputItem.activeFocus) {
            root.inputItem.forceActiveFocus();
        }
        var str = root.inputItem.text;
        var parts = str.split(":");
        if (parts.length === 3) {
            var firstColon = str.indexOf(":");
            var lastColon = str.lastIndexOf(":");
            if (root.adjustUnit === "hours") {
                root.inputItem.select(0, firstColon);
            } else if (root.adjustUnit === "seconds") {
                root.inputItem.select(lastColon + 1, str.length);
            } else {
                root.adjustUnit = "minutes";
                root.inputItem.select(firstColon + 1, lastColon);
            }
        } else if (parts.length === 2) {
            if (root.adjustUnit === "hours") {
                root.adjustUnit = "minutes";
            }
            var colonIdx = str.indexOf(":");
            if (root.adjustUnit === "seconds") {
                root.inputItem.select(colonIdx + 1, str.length);
            } else {
                root.adjustUnit = "minutes";
                root.inputItem.select(0, colonIdx);
            }
        } else {
            root.inputItem.selectAll();
        }
    }

    function focusInput() {
        Qt.callLater(() => {
            if (root.inputItem && root.inputItem.visible) {
                var sec = (root.isRunning && root.isPaused) ? root.remainingSeconds : root.totalSeconds;
                root.inputItem.text = root.formatTime(sec);
                root.inputItem.forceActiveFocus();
                root.selectActiveUnit();
            }
        });
    }

    function startFromInput() {
        var parsed = root.inputItem ? root.parseTimeInput(root.inputItem.text) : root.totalSeconds;
        if (parsed > 0) {
            root.startTimer(parsed);
            root.expanded = false;
        } else if (root.totalSeconds > 0) {
            root.startTimer(root.totalSeconds);
            root.expanded = false;
        } else {
            root.adjustTime(1, false);
        }
    }

    function activatePrimaryAction() {
        if (root.isRunning) {
            root.togglePause();
        } else {
            root.startFromInput();
        }
    }

    function onTimerFinished() {
        plasmoid.configuration.runningEndTime = 0;
        plasmoid.configuration.pausedSeconds = 0;
        var soundPath = root.resolveSoundPath();
        executable.exec("paplay --property=media.role=alarm --volume=65536 \"" + soundPath + "\" || pw-play --media-role=Notification --media-category=Playback --volume=1.0 \"" + soundPath + "\"");
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.isRunning && !root.isPaused
        onTriggered: {
            var diff = Math.max(0, Math.ceil((root.targetEndTime - Date.now()) / 1000));
            root.remainingSeconds = diff;
            if (diff <= 0) {
                root.remainingSeconds = 0;
                root.isRunning = false;
                root.isPaused = false;
                root.targetEndTime = 0;
                root.onTimerFinished();
            }
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
        }
        function exec(cmd) {
            if (cmd) {
                connectSource(cmd);
            }
        }
    }

    compactRepresentation: CompactRepresentation {
        timer: root
        configuration: plasmoid.configuration
    }

    fullRepresentation: FullRepresentation {
        timer: root
        configuration: plasmoid.configuration
    }
}
