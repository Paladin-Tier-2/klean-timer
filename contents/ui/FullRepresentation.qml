import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: full

    required property var timer
    required property var configuration

    readonly property real popupGridWidth: 17.5
    readonly property real popupGridHeight: 9.0
    readonly property real minGridWidth: 16.5
    readonly property real timerBoxGridHeight: 3.5
    readonly property real actionButtonGridHeight: 2.2

    readonly property int timeFontSixDigits: 28
    readonly property int timeFontFourDigits: 36

    readonly property real splitRatioHours: 0.33
    readonly property real splitRatioMinutes: 0.66
    readonly property real splitRatioTwoPart: 0.50

    implicitWidth: Math.round(Kirigami.Units.gridUnit * popupGridWidth)
    implicitHeight: Math.round(Kirigami.Units.gridUnit * popupGridHeight)
    Layout.minimumWidth: Math.round(Kirigami.Units.gridUnit * minGridWidth)
    Layout.minimumHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight
    focus: true

    function focusCurrentControl() {
        if (full.timer.isRunning && !full.timer.isPaused) {
            if (actionBtn) actionBtn.forceActiveFocus();
        } else {
            full.timer.selectActiveUnit();
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: full.focusCurrentControl()
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.bottomMargin: Kirigami.Units.largeSpacing
        anchors.leftMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                visible: full.timer.isRunning && !full.timer.isPaused
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * full.timerBoxGridHeight
                color: Kirigami.Theme.alternateBackgroundColor
                radius: Kirigami.Units.smallSpacing

                QQC2.Label {
                    anchors.centerIn: parent
                    text: full.timer.formatTime(full.timer.remainingSeconds)
                    font.family: "Noto Sans"
                    font.pointSize: text.length > 5 ? full.timeFontSixDigits : full.timeFontFourDigits
                    font.weight: Font.Normal
                    color: Kirigami.Theme.highlightColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: full.timer.togglePause()
                    onWheel: wheel => {
                        full.timer.adjustMinutes(wheel.angleDelta.y > 0 ? 1 : -1, wheel.modifiers & Qt.ShiftModifier);
                    }
                }
            }

            QQC2.TextField {
                id: customInput
                Component.onCompleted: full.timer.inputItem = this
                Component.onDestruction: {
                    if (full.timer.inputItem === this) full.timer.inputItem = null;
                }
                focus: true
                visible: !full.timer.isRunning || full.timer.isPaused
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * full.timerBoxGridHeight
                font.family: "Noto Sans"
                font.pointSize: text.length > 5 ? full.timeFontSixDigits : full.timeFontFourDigits
                font.weight: Font.Normal
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                topPadding: 0
                bottomPadding: 0
                placeholderText: "10:00"
                text: full.timer.formatTime(full.timer.isRunning ? full.timer.remainingSeconds : full.timer.totalSeconds)
                readOnly: true
                selectByMouse: false
                validator: RegularExpressionValidator {
                    regularExpression: /^[0-9:]*$/
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        var parts = customInput.text.split(":");
                        var ratio = mouse.x / width;
                        if (parts.length === 3) {
                            if (ratio < full.splitRatioHours) full.timer.adjustUnit = "hours";
                            else if (ratio < full.splitRatioMinutes) full.timer.adjustUnit = "minutes";
                            else full.timer.adjustUnit = "seconds";
                        } else {
                            if (ratio < full.splitRatioTwoPart) full.timer.adjustUnit = "minutes";
                            else full.timer.adjustUnit = "seconds";
                        }
                        full.timer.digitBuffer = "";
                        full.timer.selectActiveUnit();
                    }
                }

                onVisibleChanged: {
                    if (visible) {
                        Qt.callLater(() => {
                            if (visible) full.focusCurrentControl();
                        });
                    }
                }

                WheelHandler {
                    onWheel: event => {
                        full.timer.adjustMinutes(event.angleDelta.y > 0 ? 1 : -1, event.modifiers & Qt.ShiftModifier);
                    }
                }

                Keys.onLeftPressed: event => {
                    full.timer.selectPreviousUnit();
                    event.accepted = true;
                }

                Keys.onRightPressed: event => {
                    full.timer.selectNextUnit();
                    event.accepted = true;
                }

                Keys.onUpPressed: event => {
                    full.timer.adjustTime(1, event.modifiers & Qt.ShiftModifier);
                    event.accepted = true;
                }

                Keys.onDownPressed: event => {
                    full.timer.adjustTime(-1, event.modifiers & Qt.ShiftModifier);
                    event.accepted = true;
                }

                Keys.onEscapePressed: event => {
                    full.timer.expanded = false;
                    event.accepted = true;
                }

                Keys.onSpacePressed: event => {
                    full.timer.activatePrimaryAction();
                    event.accepted = true;
                }

                Keys.onReturnPressed: event => {
                    full.timer.activatePrimaryAction();
                    event.accepted = true;
                }

                Keys.onEnterPressed: event => {
                    full.timer.activatePrimaryAction();
                    event.accepted = true;
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
                        full.timer.clearCurrentUnit();
                        event.accepted = true;
                        return;
                    }
                    if (event.text >= "0" && event.text <= "9" && event.text.length === 1) {
                        full.timer.applyDigit(event.text);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Colon || event.text === ":") {
                        full.timer.digitBuffer = "";
                        full.timer.selectNextUnit();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_R && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ControlModifier)) {
                        full.timer.resetTimer();
                        event.accepted = true;
                        return;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing + 2

            QQC2.Button {
                Layout.fillWidth: true
                text: "-5m"
                focusPolicy: Qt.NoFocus
                onClicked: full.timer.adjustMinutes(-1, true)
            }
            QQC2.Button {
                Layout.fillWidth: true
                text: "-1m"
                focusPolicy: Qt.NoFocus
                onClicked: full.timer.adjustMinutes(-1, false)
            }
            QQC2.Button {
                Layout.fillWidth: true
                text: "+1m"
                focusPolicy: Qt.NoFocus
                onClicked: full.timer.adjustMinutes(1, false)
            }
            QQC2.Button {
                Layout.fillWidth: true
                text: "+5m"
                focusPolicy: Qt.NoFocus
                onClicked: full.timer.adjustMinutes(1, true)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing + 2

            QQC2.Button {
                id: actionBtn
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * full.actionButtonGridHeight
                text: !full.timer.isRunning ? i18n("Start") : (full.timer.isPaused ? i18n("Resume") : i18n("Pause"))
                icon.name: !full.timer.isRunning ? "media-playback-start" : (full.timer.isPaused ? "media-playback-start" : "media-playback-pause")
                highlighted: true

                Keys.onLeftPressed: event => {
                    full.timer.selectPreviousUnit();
                    event.accepted = true;
                }

                Keys.onRightPressed: event => {
                    full.timer.selectNextUnit();
                    event.accepted = true;
                }

                Keys.onUpPressed: event => {
                    full.timer.adjustTime(1, event.modifiers & Qt.ShiftModifier);
                    if (!full.timer.isRunning && full.timer.inputItem && full.timer.inputItem.visible) {
                        full.timer.inputItem.forceActiveFocus();
                    }
                    event.accepted = true;
                }

                Keys.onDownPressed: event => {
                    full.timer.adjustTime(-1, event.modifiers & Qt.ShiftModifier);
                    if (!full.timer.isRunning && full.timer.inputItem && full.timer.inputItem.visible) {
                        full.timer.inputItem.forceActiveFocus();
                    }
                    event.accepted = true;
                }

                Keys.onEscapePressed: event => {
                    full.timer.expanded = false;
                    event.accepted = true;
                }

                Keys.onSpacePressed: event => {
                    full.timer.activatePrimaryAction();
                    event.accepted = true;
                }

                Keys.onReturnPressed: event => {
                    full.timer.activatePrimaryAction();
                    event.accepted = true;
                }

                Keys.onEnterPressed: event => {
                    full.timer.activatePrimaryAction();
                    event.accepted = true;
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_R) {
                        full.timer.resetTimer();
                        event.accepted = true;
                    }
                }

                onClicked: {
                    full.timer.activatePrimaryAction();
                }
            }

            QQC2.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * full.actionButtonGridHeight
                text: i18n("Reset (R)")
                icon.name: "media-playback-stop"
                focusPolicy: Qt.NoFocus
                enabled: full.timer.isRunning || full.timer.remainingSeconds > 0 || full.timer.totalSeconds > 0
                onClicked: {
                    full.timer.resetTimer();
                }
            }
        }
    }

    Connections {
        target: full.timer
        function onExpandedChanged() {
            if (full.timer.expanded) {
                Qt.callLater(() => {
                    if (full.timer.expanded) full.focusCurrentControl();
                });
            } else {
                if (full.timer.compactItem) {
                    full.timer.compactItem.forceActiveFocus();
                }
            }
        }
        function onIsRunningChanged() {
            if (full.timer.expanded) {
                Qt.callLater(() => {
                    if (full.timer.expanded) full.focusCurrentControl();
                });
            }
        }
        function onIsPausedChanged() {
            if (full.timer.expanded) {
                Qt.callLater(() => {
                    if (full.timer.expanded) full.focusCurrentControl();
                });
            }
        }
    }

    Keys.onEscapePressed: event => {
        full.timer.expanded = false;
        event.accepted = true;
    }

    Keys.onSpacePressed: event => {
        full.timer.activatePrimaryAction();
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_R) {
            full.timer.resetTimer();
            event.accepted = true;
        }
    }

    Keys.onLeftPressed: event => {
        full.timer.selectPreviousUnit();
        event.accepted = true;
    }

    Keys.onRightPressed: event => {
        full.timer.selectNextUnit();
        event.accepted = true;
    }

    Keys.onUpPressed: event => {
        if (!full.timer.isRunning && full.timer.inputItem && full.timer.inputItem.visible) {
            full.timer.inputItem.forceActiveFocus();
        }
        full.timer.adjustTime(1, event.modifiers & Qt.ShiftModifier);
        event.accepted = true;
    }

    Keys.onDownPressed: event => {
        if (!full.timer.isRunning && full.timer.inputItem && full.timer.inputItem.visible) {
            full.timer.inputItem.forceActiveFocus();
        }
        full.timer.adjustTime(-1, event.modifiers & Qt.ShiftModifier);
        event.accepted = true;
    }

    Keys.onReturnPressed: event => {
        full.timer.activatePrimaryAction();
        event.accepted = true;
    }

    Keys.onEnterPressed: event => {
        full.timer.activatePrimaryAction();
        event.accepted = true;
    }
}
