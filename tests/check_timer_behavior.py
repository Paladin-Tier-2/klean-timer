#!/usr/bin/env python3
"""Run with Python and PySide6: python3 tests/check_timer_behavior.py"""

import os
import re
import shlex
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import Property, QObject, QPoint, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QJSEngine
from PySide6.QtQuick import QQuickItem, QQuickView
from PySide6.QtTest import QTest

SOURCE = Path(__file__).parents[1] / "contents/ui/main.qml"
FULL_SOURCE = Path(__file__).parents[1] / "contents/ui/FullRepresentation.qml"


def block_at(source, marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 0
    for end in range(opening, len(source)):
        depth += (source[end] == "{") - (source[end] == "}")
        if depth == 0:
            return source[start : end + 1]
    raise ValueError(f"Unclosed QML block: {marker}")


def test_parse_time_input():
    source = SOURCE.read_text()
    engine = QJSEngine()
    parse_fn = block_at(source, "function parseTimeInput(")
    engine.evaluate(parse_fn)

    cases = [
        ("00:00", 0),
        ("0", 0),
        ("0:00", 0),
        ("00:00:00", 0),
        ("0m", 0),
        ("0s", 0),
        ("", 0),
        ("01:00", 60),
        ("1", 60),
        ("1m", 60),
        ("30s", 30),
        ("1h", 3600),
        ("01:30", 90),
        ("bad", -1),
        ("12:xx", -1),
    ]
    for inp, expected in cases:
        res = engine.evaluate(f'parseTimeInput("{inp}")')
        assert not res.isError(), f"Error parsing {inp}: {res.toString()}"
        actual = res.toInt()
        assert actual == expected, (
            f"parseTimeInput('{inp}'): expected {expected}, got {actual}"
        )
    print("PASS: parseTimeInput handles 0, formats, and invalid inputs correctly")


def test_adjust_time_from_zero():
    source = SOURCE.read_text()
    engine = QJSEngine()
    engine.evaluate(block_at(source, "function formatTime("))
    engine.evaluate(block_at(source, "function parseTimeInput("))
    engine.evaluate(block_at(source, "function adjustTime("))

    js = """
        var plasmoid = { configuration: { lastSeconds: 0, runningEndTime: 0, pausedSeconds: 0 } };
        var root = {
            totalSeconds: 0,
            remainingSeconds: 0,
            isRunning: false,
            isPaused: false,
            adjustUnit: "minutes",
            inputItem: { text: "00:00", visible: true },
            formatTime: formatTime,
            parseTimeInput: parseTimeInput,
            selectActiveUnit: function() {}
        };
        root.adjustTime = adjustTime;

        root.adjustTime(1, false);
        var t1 = root.totalSeconds;
        var txt1 = root.inputItem.text;

        root.totalSeconds = 0;
        root.inputItem.text = "00:00";
        root.adjustTime(-1, false);
        var t2 = root.totalSeconds;
        var txt2 = root.inputItem.text;

        root.totalSeconds = 0;
        root.adjustUnit = "seconds";
        root.inputItem.text = "00:00";
        root.adjustTime(1, false);
        var t3 = root.totalSeconds;
        var txt3 = root.inputItem.text;

        root.totalSeconds = 0;
        root.adjustTime(-1, false);
        var t4 = root.totalSeconds;

        ({ t1: t1, txt1: txt1, t2: t2, txt2: txt2, t3: t3, txt3: txt3, t4: t4 })
    """
    res = engine.evaluate(js)
    assert not res.isError(), res.toString()
    obj = res.toVariant()
    assert obj["t1"] == 60 and obj["txt1"] == "01:00", (
        f"Up from 0 minutes failed: {obj}"
    )
    assert obj["t2"] == 0 and obj["txt2"] == "00:00", (
        f"Down from 0 minutes failed: {obj}"
    )
    assert obj["t3"] == 1 and obj["txt3"] == "00:01", f"Up from 0 seconds failed: {obj}"
    assert obj["t4"] == 0, f"Down from 0 seconds failed: {obj}"
    print("PASS: adjustTime from 0 increments and clamps correctly")


def test_adjust_minutes_consistency():
    source = SOURCE.read_text()
    engine = QJSEngine()
    engine.evaluate(block_at(source, "function formatTime("))
    engine.evaluate(block_at(source, "function parseTimeInput("))
    engine.evaluate(block_at(source, "function adjustTime("))
    engine.evaluate(block_at(source, "function adjustMinutes("))

    js = """
        var plasmoid = { configuration: { lastSeconds: 0, runningEndTime: 0, pausedSeconds: 0 } };
        var root = {
            totalSeconds: 30,
            remainingSeconds: 0,
            isRunning: false,
            isPaused: false,
            adjustUnit: "seconds",
            inputItem: { text: "00:30", visible: true },
            formatTime: formatTime,
            parseTimeInput: parseTimeInput,
            selectActiveUnit: function() {}
        };
        root.adjustTime = adjustTime;
        root.adjustMinutes = adjustMinutes;

        root.adjustMinutes(1, false);
        var t1 = root.totalSeconds;
        var unit1 = root.adjustUnit;

        root.adjustMinutes(-1, false);
        var t2 = root.totalSeconds;

        root.adjustMinutes(1, true);
        var t3 = root.totalSeconds;

        ({ t1: t1, unit1: unit1, t2: t2, t3: t3 })
    """
    res = engine.evaluate(js)
    assert not res.isError(), res.toString()
    obj = res.toVariant()
    assert obj["t1"] == 90 and obj["unit1"] == "minutes", f"adjustMinutes up failed: {obj}"
    assert obj["t2"] == 30, f"adjustMinutes down failed: {obj}"
    assert obj["t3"] == 330, f"adjustMinutes shift failed: {obj}"
    print("PASS: adjustMinutes consistently adds minutes regardless of prior unit")


def test_adjust_seconds_consistency():
    source = SOURCE.read_text()
    engine = QJSEngine()
    engine.evaluate(block_at(source, "function formatTime("))
    engine.evaluate(block_at(source, "function parseTimeInput("))
    engine.evaluate(block_at(source, "function adjustTime("))
    engine.evaluate(block_at(source, "function adjustSeconds("))

    js = """
        var plasmoid = { configuration: { lastSeconds: 0, runningEndTime: 0, pausedSeconds: 0 } };
        var root = {
            totalSeconds: 60,
            remainingSeconds: 0,
            isRunning: false,
            isPaused: false,
            adjustUnit: "minutes",
            inputItem: { text: "01:00", visible: true },
            formatTime: formatTime,
            parseTimeInput: parseTimeInput,
            selectActiveUnit: function() {}
        };
        root.adjustTime = adjustTime;
        root.adjustSeconds = adjustSeconds;

        root.adjustSeconds(1, false);
        var t1 = root.totalSeconds;
        var unit1 = root.adjustUnit;

        root.adjustSeconds(-1, false);
        var t2 = root.totalSeconds;

        root.adjustSeconds(1, true);
        var t3 = root.totalSeconds;

        ({ t1: t1, unit1: unit1, t2: t2, t3: t3 })
    """
    res = engine.evaluate(js)
    assert not res.isError(), res.toString()
    obj = res.toVariant()
    assert obj["t1"] == 61 and obj["unit1"] == "seconds", f"adjustSeconds up failed: {obj}"
    assert obj["t2"] == 60, f"adjustSeconds down failed: {obj}"
    assert obj["t3"] == 70, f"adjustSeconds shift failed: {obj}"
    print("PASS: adjustSeconds consistently adds seconds regardless of prior unit")


def test_timer_reset_and_state():
    source = SOURCE.read_text()
    target_time = re.search(r"property real targetEndTime:\s*(.+)", source).group(1)
    remaining = (
        re.search(
            r"property int remainingSeconds:\s*(.*?)\n\s*property bool isRunning",
            source,
            re.S,
        )
        .group(1)
        .strip()
    )
    is_running = re.search(r"property bool isRunning:\s*(.+)", source).group(1)
    is_paused = re.search(r"property bool isPaused:\s*(.+)", source).group(1)

    restore = f"""
        function restore() {{
            var root = {{}};
            root.targetEndTime = {target_time};
            root.remainingSeconds = {remaining};
            root.isRunning = {is_running};
            root.isPaused = {is_paused};
            return root;
        }}
    """
    scenario = """
        var now = 1000000;
        Date.now = function() { return now; };
        var plasmoid = { configuration: { lastSeconds: 300, runningEndTime: 0, pausedSeconds: 0 } };
        var root = {
            totalSeconds: 300, remainingSeconds: 0, targetEndTime: 0,
            isRunning: false, isPaused: false, adjustUnit: "minutes",
            inputItem: { visible: true, text: "12:00" },
            parseTimeInput: parseTimeInput,
            formatTime: formatTime,
            selectActiveUnit: function() {},
            focusInput: function() {}
        };
        root.adjustTime = adjustTime;
        root.startTimer = startTimer;
        root.togglePause = togglePause;
        root.resetTimer = resetTimer;

        root.startTimer(300);
        if (!root.isRunning || root.remainingSeconds !== 300) throw Error("Timer did not start");

        root.resetTimer();
        if (root.isRunning || root.remainingSeconds !== 0) throw Error("Running timer did not reset");

        root.resetTimer();
        if (root.totalSeconds !== 0) throw Error("Resetting stopped timer did not reset to 0");

        root.inputItem.text = "00:00";
        root.adjustTime(1, false);
        if (root.totalSeconds !== 60) throw Error("Adjust from reset 0 did not increment to 60");

        true;
    """
    engine = QJSEngine()
    result = engine.evaluate(
        "\n".join(
            [
                block_at(source, "function formatTime("),
                block_at(source, "function parseTimeInput("),
                block_at(source, "function adjustTime("),
                block_at(source, "function startTimer("),
                block_at(source, "function togglePause("),
                block_at(source, "function resetTimer("),
                restore,
                scenario,
            ]
        )
    )
    assert not result.isError(), result.toString()
    print(
        "PASS: timer reset (both running and stopped) and adjust from 0 work properly"
    )


def test_enter_does_not_immediately_pause_timer():
    source = SOURCE.read_text()
    full_source = FULL_SOURCE.read_text()
    full = block_at(full_source, "Item {")
    full_return = block_at(full, "Keys.onReturnPressed:")
    full_enter = block_at(full, "Keys.onEnterPressed:")
    input_qml = block_at(full_source, "QQC2.TextField {")
    input_return = block_at(input_qml, "Keys.onReturnPressed:")
    input_enter = block_at(input_qml, "Keys.onEnterPressed:")
    timer_functions = "\n".join(
        block_at(source, marker)
        for marker in (
            "function formatTime(",
            "function parseTimeInput(",
            "function startTimer(",
            "function togglePause(",
            "function startFromInput(",
            "function activatePrimaryAction(",
        )
    )
    qml = f"""
        import QtQuick
        import QtQuick.Controls as QQC2
        FocusScope {{
            id: root
            width: 240; height: 100; visible: true; focus: true
            property int totalSeconds: 300
            property real targetEndTime: 0
            property int remainingSeconds: 0
            property bool isRunning: targetEndTime > 0 || plasmoid.configuration.pausedSeconds > 0
            property bool isPaused: plasmoid.configuration.pausedSeconds > 0
            property bool expanded: true
            property var inputItem: null
            QtObject {{ id: plasmoid; property var configuration: ({{lastSeconds: 300, runningEndTime: 0, pausedSeconds: 0}}) }}
            {timer_functions}
            function adjustTime(direction, isShift) {{}}
            Item {{
                id: full; width: 240; height: 100; focus: true; visible: root.expanded
                property var timer: root
                {full_return}
                {full_enter}
                QQC2.TextField {{
                    id: customInput; objectName: "input"; width: 240; height: 60
                    focus: true; text: "10:00"
                    Component.onCompleted: root.inputItem = this
                    {input_return}
                    {input_enter}
                }}
            }}
        }}
    """
    app = QGuiApplication.instance() or QGuiApplication([])
    with tempfile.NamedTemporaryFile(mode="w", suffix=".qml") as qml_file:
        qml_file.write(qml)
        qml_file.flush()
        view = QQuickView()
        view.setSource(QUrl.fromLocalFile(qml_file.name))
        assert view.status() == QQuickView.Status.Ready, [
            error.toString() for error in view.errors()
        ]
        view.show()
        app.processEvents()
        root = view.rootObject()
        field = root.findChild(QQuickItem, "input")
        field.forceActiveFocus()
        field.setProperty("text", "10:00")
        QTest.keyClick(view, Qt.Key_Return)
        QTest.qWait(30)
        app.processEvents()
        assert root.property("expanded") is False
        assert root.property("isRunning")
        assert not root.property("isPaused"), (
            "Return started the timer, then bubbled and paused it"
        )
        assert root.property("remainingSeconds") == 600
        view.close()
    print("PASS: Enter starts without immediately pausing the timer")


def test_space_key_starts_timer_without_eating_characters():
    source = SOURCE.read_text()
    full_source = FULL_SOURCE.read_text()
    full_space = block_at(full_source, "Keys.onSpacePressed:")
    input_space = block_at(
        full_source[full_source.index("id: customInput") :],
        "Keys.onSpacePressed:",
    )
    timer_functions = "\n".join(
        block_at(source, f)
        for f in (
            "function formatTime(",
            "function parseTimeInput(",
            "function startTimer(",
            "function togglePause(",
            "function startFromInput(",
            "function activatePrimaryAction(",
        )
    )
    qml = f"""
        import QtQuick
        import QtQuick.Controls as QQC2
        FocusScope {{
            id: root
            width: 240; height: 100; visible: true; focus: true
            property int totalSeconds: 1500
            property real targetEndTime: 0
            property int remainingSeconds: 0
            property bool isRunning: targetEndTime > 0 || plasmoid.configuration.pausedSeconds > 0
            property bool isPaused: plasmoid.configuration.pausedSeconds > 0
            property bool expanded: true
            property var inputItem: null
            QtObject {{ id: plasmoid; property var configuration: ({{lastSeconds: 1500, runningEndTime: 0, pausedSeconds: 0}}) }}
            {timer_functions}
            function adjustTime(direction, isShift) {{}}
            Item {{
                id: full; width: 240; height: 100; focus: true; visible: root.expanded
                property var timer: root
                {full_space}
                QQC2.TextField {{
                    id: customInput; objectName: "input"; width: 240; height: 60
                    focus: true; text: "25:00"
                    validator: RegularExpressionValidator {{ regularExpression: /^[0-9:]*$/ }}
                    Component.onCompleted: root.inputItem = this
                    {input_space}
                }}
            }}
        }}
    """
    app = QGuiApplication.instance() or QGuiApplication([])
    with tempfile.NamedTemporaryFile(mode="w", suffix=".qml") as qml_file:
        qml_file.write(qml)
        qml_file.flush()
        view = QQuickView()
        view.setSource(QUrl.fromLocalFile(qml_file.name))
        assert view.status() == QQuickView.Status.Ready, [
            error.toString() for error in view.errors()
        ]
        view.show()
        app.processEvents()
        root = view.rootObject()
        field = root.findChild(QQuickItem, "input")
        field.forceActiveFocus()
        field.setProperty("text", "25:00")
        field.select(3, 5)
        assert field.property("selectedText") == "00"
        QTest.keyClick(view, Qt.Key_Space)
        QTest.qWait(30)
        app.processEvents()
        assert field.property("text") == "25:00"
        assert root.property("isRunning")
        assert not root.property("isPaused")
        assert root.property("remainingSeconds") == 1500
        view.close()
    print("PASS: Space starts timer without eating character or corrupting text")


def test_backspace_and_digit_entry_preserves_colons():
    source = SOURCE.read_text()
    full_source = FULL_SOURCE.read_text()
    input_keys = block_at(
        full_source[full_source.index("id: customInput") :],
        "Keys.onPressed:",
    )
    timer_functions = "\n".join(
        block_at(source, f)
        for f in (
            "function formatTime(",
            "function parseTimeInput(",
            "function selectActiveUnit(",
            "function selectPreviousUnit(",
            "function selectNextUnit(",
            "function clearCurrentUnit(",
            "function applyDigit(",
            "function adjustTime(",
        )
    )
    qml = f"""
        import QtQuick
        import QtQuick.Controls as QQC2
        Item {{
            id: root
            width: 320; height: 160
            property int totalSeconds: 1500
            property string adjustUnit: "minutes"
            property string digitBuffer: ""
            property bool isRunning: false
            property var inputItem: null
            QtObject {{ id: plasmoid; property var configuration: ({{lastSeconds: 1500}}) }}
            {timer_functions}

            Item {{
                id: full
                property var timer: root
                QQC2.TextField {{
                    id: customInput; objectName: "input"; width: 320; height: 60
                    readOnly: true; focus: true
                    text: root.formatTime(root.totalSeconds)
                    Component.onCompleted: {{
                        root.inputItem = this;
                        root.selectActiveUnit();
                    }}
                    {input_keys}
                }}
            }}
        }}
    """
    app = QGuiApplication.instance() or QGuiApplication([])
    with tempfile.NamedTemporaryFile(mode="w", suffix=".qml") as qml_file:
        qml_file.write(qml)
        qml_file.flush()
        view = QQuickView()
        view.setSource(QUrl.fromLocalFile(qml_file.name))
        assert view.status() == QQuickView.Status.Ready, [
            error.toString() for error in view.errors()
        ]
        view.show()
        app.processEvents()
        root = view.rootObject()
        field = root.findChild(QQuickItem, "input")
        field.forceActiveFocus()
        assert field.property("text") == "25:00"
        assert field.property("selectedText") == "25"

        for _ in range(5):
            QTest.keyClick(view, Qt.Key_Backspace)
            app.processEvents()
        assert field.property("text") == "00:00"
        assert field.property("selectedText") == "00"
        assert ":" in field.property("text")

        QTest.keyClick(view, Qt.Key_1)
        app.processEvents()
        assert field.property("text") == "01:00"
        assert field.property("selectedText") == "01"

        QTest.keyClick(view, Qt.Key_5)
        app.processEvents()
        assert field.property("text") == "15:00"
        assert field.property("selectedText") == "15"

        QTest.keyClick(view, Qt.Key_Colon)
        app.processEvents()
        assert field.property("text") == "15:00"
        assert field.property("selectedText") == "00"

        QTest.keyClick(view, Qt.Key_3)
        app.processEvents()
        assert field.property("text") == "15:03"
        assert field.property("selectedText") == "03"

        QTest.keyClick(view, Qt.Key_Backspace)
        app.processEvents()
        assert field.property("text") == "15:00"
        assert field.property("selectedText") == "00"

        view.close()
    print("PASS: Backspace and digit entry preserve colons and active unit selection")


def test_paused_state_shows_highlight_box():
    source = SOURCE.read_text()
    timer_functions = "\n".join(
        block_at(source, f)
        for f in (
            "function formatTime(",
            "function parseTimeInput(",
            "function selectActiveUnit(",
            "function clearCurrentUnit(",
            "function applyDigit(",
            "function adjustTime(",
            "function focusInput(",
            "function activatePrimaryAction(",
        )
    )
    qml = f"""
        import QtQuick
        import QtQuick.Controls as QQC2
        FocusScope {{
            id: root
            width: 320; height: 160; visible: true; focus: true
            property int totalSeconds: 1500
            property real targetEndTime: 0
            property int remainingSeconds: 481
            property bool isRunning: false
            property bool isPaused: false
            property string adjustUnit: "minutes"
            property string digitBuffer: ""
            property bool expanded: true
            property var inputItem: null
            QtObject {{ id: plasmoid; property var configuration: ({{lastSeconds: 1500, runningEndTime: 0, pausedSeconds: 0}}) }}
            {timer_functions}

            Item {{
                id: full; width: 320; height: 160; focus: true; visible: root.expanded
                property var timer: root

                Rectangle {{
                    objectName: "runningLabel"
                    visible: root.isRunning && !root.isPaused
                }}

                QQC2.TextField {{
                    id: customInput; objectName: "input"; width: 320; height: 60
                    readOnly: true; focus: true
                    visible: !root.isRunning || root.isPaused
                    text: root.formatTime(root.isRunning ? root.remainingSeconds : root.totalSeconds)
                    Component.onCompleted: {{
                        root.inputItem = this;
                        root.selectActiveUnit();
                    }}
                }}
            }}
        }}
    """
    app = QGuiApplication.instance() or QGuiApplication([])
    with tempfile.NamedTemporaryFile(mode="w", suffix=".qml") as qml_file:
        qml_file.write(qml)
        qml_file.flush()
        view = QQuickView()
        view.setSource(QUrl.fromLocalFile(qml_file.name))
        assert view.status() == QQuickView.Status.Ready, [
            error.toString() for error in view.errors()
        ]
        view.show()
        app.processEvents()
        root = view.rootObject()
        field = root.findChild(QQuickItem, "input")
        running_lbl = root.findChild(QQuickItem, "runningLabel")

        assert field.property("visible") is True
        assert running_lbl.property("visible") is False
        assert field.property("text") == "25:00"
        assert field.property("selectedText") == "25"

        root.setProperty("isRunning", True)
        root.setProperty("isPaused", False)
        app.processEvents()
        assert field.property("visible") is False
        assert running_lbl.property("visible") is True

        root.setProperty("isPaused", True)
        root.setProperty("remainingSeconds", 481)
        root.focusInput()
        QTest.qWait(30)
        app.processEvents()
        assert field.property("visible") is True
        assert running_lbl.property("visible") is False
        assert field.property("text") == "08:01"
        assert field.property("selectedText") == "08"

        view.close()
    print("PASS: Paused state shows input field with active unit highlighted")


def test_hours_navigation_and_adjustment():
    source = SOURCE.read_text()
    engine = QJSEngine()
    engine.evaluate(block_at(source, "function formatTime("))
    engine.evaluate(block_at(source, "function parseTimeInput("))
    engine.evaluate(block_at(source, "function adjustTime("))
    engine.evaluate(block_at(source, "function selectPreviousUnit("))
    engine.evaluate(block_at(source, "function selectNextUnit("))
    engine.evaluate(block_at(source, "function selectActiveUnit("))

    js = """
        var plasmoid = { configuration: { lastSeconds: 2592, runningEndTime: 0, pausedSeconds: 0 } };
        var selection = { start: -1, end: -1 };
        var input = {
            text: "43:12",
            visible: true,
            activeFocus: true,
            select: function(s, e) { selection.start = s; selection.end = e; },
            selectAll: function() { selection.start = 0; selection.end = this.text.length; },
            forceActiveFocus: function() {}
        };
        var root = {
            totalSeconds: 2592,
            remainingSeconds: 0,
            isRunning: false,
            isPaused: false,
            adjustUnit: "minutes",
            inputItem: input,
            formatTime: formatTime,
            parseTimeInput: parseTimeInput
        };
        root.adjustTime = adjustTime;
        root.selectActiveUnit = selectActiveUnit;
        root.selectPreviousUnit = selectPreviousUnit;
        root.selectNextUnit = selectNextUnit;

        root.selectActiveUnit();
        var sel1 = { s: selection.start, e: selection.end, u: root.adjustUnit, t: input.text };

        root.selectPreviousUnit();
        var sel2 = { s: selection.start, e: selection.end, u: root.adjustUnit, t: input.text };

        root.selectNextUnit();
        var sel3 = { s: selection.start, e: selection.end, u: root.adjustUnit, t: input.text };

        root.totalSeconds = 6192;
        input.text = root.formatTime(root.totalSeconds);
        root.adjustUnit = "minutes";
        root.selectActiveUnit();
        var sel4 = { s: selection.start, e: selection.end, u: root.adjustUnit, t: input.text };

        root.selectPreviousUnit();
        var sel5 = { s: selection.start, e: selection.end, u: root.adjustUnit, t: input.text };

        root.adjustTime(1, false);
        var sel6 = { s: selection.start, e: selection.end, u: root.adjustUnit, t: input.text, sec: root.totalSeconds };

        root.adjustTime(-2, false);
        var sel7 = { s: selection.start, e: selection.end, u: root.adjustUnit, t: input.text, sec: root.totalSeconds };

        ({ sel1: sel1, sel2: sel2, sel3: sel3, sel4: sel4, sel5: sel5, sel6: sel6, sel7: sel7 })
    """
    res = engine.evaluate(js)
    assert not res.isError(), res.toString()
    r = res.toVariant()
    assert r["sel1"]["u"] == "minutes" and r["sel1"]["s"] == 0 and r["sel1"]["e"] == 2 and r["sel1"]["t"] == "43:12"
    assert r["sel2"]["u"] == "minutes" and r["sel2"]["s"] == 0 and r["sel2"]["e"] == 2 and r["sel2"]["t"] == "43:12"
    assert r["sel3"]["u"] == "seconds" and r["sel3"]["s"] == 3 and r["sel3"]["e"] == 5 and r["sel3"]["t"] == "43:12"
    assert r["sel4"]["u"] == "minutes" and r["sel4"]["s"] == 3 and r["sel4"]["e"] == 5 and r["sel4"]["t"] == "01:43:12"
    assert r["sel5"]["u"] == "hours" and r["sel5"]["s"] == 0 and r["sel5"]["e"] == 2 and r["sel5"]["t"] == "01:43:12"
    assert r["sel6"]["u"] == "hours" and r["sel6"]["sec"] == 9792 and r["sel6"]["t"] == "02:43:12"
    assert r["sel7"]["u"] == "minutes" and r["sel7"]["sec"] == 2592 and r["sel7"]["t"] == "43:12"
    print("PASS: hours navigation and adjustment works correctly")


def test_timer_finished_audio_command():
    source = SOURCE.read_text()
    fn = block_at(source, "function onTimerFinished()")
    assert 'media.role=alarm' in fn
    assert 'media-role=Notification' in fn
    assert 'paplay' in fn
    assert 'pw-play' in fn
    print("PASS: onTimerFinished uses prioritized alarm/notification audio pipeline")



def test_wheel_accumulation_and_modifiers():
    source = SOURCE.read_text()
    engine = QJSEngine()
    functions = "\n".join(
        block_at(source, name)
        for name in ("function handleWheel(", "function adjustMinutes(", "function adjustSeconds(")
    )
    js = """
        var Qt = { ControlModifier: 0x04000000, ShiftModifier: 0x02000000 };
        var root = {
            wheelAngleRemainder: 0, wheelPixelRemainder: 0, wheelModifiers: 0,
            wheelAngleStep: 120, wheelPixelStep: 40,
            changes: [],
            adjustMinutes: function(n, shift) { this.changes.push(["m", n, shift]); },
            adjustSeconds: function(n, shift) { this.changes.push(["s", n, shift]); }
        };
        root.handleWheel = handleWheel;
        root.handleWheel(0, 0, 0);
        root.handleWheel(0, undefined, 0);
        root.handleWheel(undefined, undefined, 0);
        root.handleWheel(60, 0, 0);
        root.handleWheel(60, 0, 0);
        root.handleWheel(0, 15, 0);
        root.handleWheel(0, 25, 0);
        root.handleWheel(-240, 0, Qt.ControlModifier | Qt.ShiftModifier);
        root.changes;
    """
    result = engine.evaluate(functions + "\n" + js)
    assert not result.isError(), result.toString()
    assert result.toVariant() == [
        ["m", 1, False], ["m", 1, False], ["s", -2, True]
    ]
    assert "wheel.pixelDelta ? wheel.pixelDelta.y : 0" in (
        Path(__file__).parents[1] / "contents/ui/CompactRepresentation.qml"
    ).read_text()
    assert "event.pixelDelta ? event.pixelDelta.y : 0" in FULL_SOURCE.read_text()


def test_running_adjustment_uses_deadline():
    source = SOURCE.read_text()
    engine = QJSEngine()
    fn = block_at(source, "function adjustTime(")
    js = """
        var now = 2000000;
        Date.now = function() { return now; };
        var plasmoid = {configuration: {runningEndTime: 0, pausedSeconds: 0}};
        var root = {
            isRunning: true, isPaused: false, remainingSeconds: 250,
            targetEndTime: now + 10000, adjustUnit: "seconds", digitBuffer: "",
            inputItem: null, onTimerFinished: function() { this.finished = true; }
        };
        root.adjustTime = adjustTime;
        root.adjustTime(1, false);
        var correct = root.remainingSeconds === 11;
        root.targetEndTime = now - 1000;
        root.remainingSeconds = 40;
        root.adjustTime(1, false);
        [correct, root.remainingSeconds, root.isRunning, root.finished === true];
    """
    result = engine.evaluate(fn + "\n" + js)
    assert not result.isError(), result.toString()
    assert result.toVariant() == [True, 0, False, True]


def test_alarm_fallback_command():
    source = SOURCE.read_text()
    fn = block_at(source, "function onTimerFinished()")
    engine = QJSEngine()
    js = """
        var command = "";
        var plasmoid = {configuration: {}};
        var executable = {exec: function(c) { command = c; }};
        var root = {
            maxPulseVolume: 65536,
            resolveSoundPath: function() { return "/tmp/audio's alarm.oga"; }
        };
        root.onTimerFinished = onTimerFinished;
        root.onTimerFinished();
        command;
    """
    result = engine.evaluate(fn + "\n" + js)
    assert not result.isError(), result.toString()
    command = result.toString()
    assert "alarm-clock-elapsed.oga" in command
    assert command.count("paplay ") == 2 and command.count("pw-play ") == 2
    assert shlex.split(command).count("/tmp/audio's alarm.oga") == 2
    assert shlex.split(command).count("/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga") == 2



def main():
    app = QGuiApplication.instance() or QGuiApplication([])
    test_parse_time_input()
    test_adjust_time_from_zero()
    test_adjust_minutes_consistency()
    test_adjust_seconds_consistency()
    test_timer_reset_and_state()
    test_enter_does_not_immediately_pause_timer()
    test_space_key_starts_timer_without_eating_characters()
    test_backspace_and_digit_entry_preserves_colons()
    test_paused_state_shows_highlight_box()
    test_hours_navigation_and_adjustment()
    test_timer_finished_audio_command()
    test_wheel_accumulation_and_modifiers()
    test_running_adjustment_uses_deadline()
    test_alarm_fallback_command()
    print("ALL TESTS PASSED!")


if __name__ == "__main__":
    main()
