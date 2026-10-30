import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

MouseArea {
    id: compactRoot

    required property PlasmoidItem timer
    required property var configuration

    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int panelThickness: isVertical
        ? (compactRoot.width > 0 ? compactRoot.width : (compactRoot.timer.width > 0 ? compactRoot.timer.width : 28))
        : (compactRoot.height > 0 ? compactRoot.height : (compactRoot.timer.height > 0 ? compactRoot.timer.height : 28))

    readonly property bool autoScale: compactRoot.configuration.autoScale !== undefined ? compactRoot.configuration.autoScale : true
    readonly property int iconSize: compactRoot.autoScale
        ? compactRoot.calcAutoIconSize(compactRoot.panelThickness)
        : (compactRoot.configuration.iconSize > 0 ? compactRoot.configuration.iconSize : 26)
    readonly property int fontSize: compactRoot.autoScale
        ? compactRoot.calcAutoFontSize(compactRoot.panelThickness)
        : (compactRoot.configuration.timerFontSize > 0 ? compactRoot.configuration.timerFontSize : 13)

    readonly property bool effectiveTintIcon: compactRoot.configuration.tintIcon !== undefined ? compactRoot.configuration.tintIcon : true
    readonly property var presetIconMap: ({
        "sleek-circle": "sleek-play-circle.svg",
        "pomodoro": "pomodoro-start-light.svg",
        "frame": "pomodoro-frame-light.svg",
        "pause-circle": "sleek-pause-circle.svg"
    })
    readonly property var effectiveIconSource: {
        var mode = compactRoot.configuration.iconType || "sleek-circle";
        if (mode === "custom" && compactRoot.configuration.customSvgPath) {
            var path = ("" + compactRoot.configuration.customSvgPath).trim();
            if (path.startsWith("file://") || path.startsWith("/")) {
                return path.startsWith("file://") ? path : "file://" + path;
            }
            return "file://" + path;
        }
        var filename = compactRoot.presetIconMap[mode] || "sleek-play-circle.svg";
        return Qt.resolvedUrl("../icons/" + filename);
    }

    Layout.minimumWidth: Kirigami.Units.iconSizes.small
    Layout.minimumHeight: Kirigami.Units.iconSizes.small
    Layout.preferredWidth: {
        if (compactRoot.isVertical) {
            return compactRoot.timer.isRunning ? Math.max(compactRoot.panelThickness, timerLabel.implicitWidth + 8) : compactRoot.panelThickness;
        }
        if (compactRoot.timer.isRunning) {
            return timerLabel.implicitWidth + Kirigami.Units.smallSpacing * 2;
        }
        return Math.max(compactRoot.iconSize, compactRoot.panelThickness);
    }
    Layout.preferredHeight: compactRoot.isVertical
        ? (compactRoot.timer.isRunning ? timerLabel.implicitHeight + Kirigami.Units.smallSpacing * 2 : compactRoot.iconSize)
        : compactRoot.panelThickness
    Layout.fillWidth: compactRoot.isVertical
    Layout.fillHeight: true

    clip: true
    focus: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    hoverEnabled: true

    Component.onCompleted: compactRoot.timer.compactItem = this
    Component.onDestruction: {
        if (compactRoot.timer.compactItem === this) compactRoot.timer.compactItem = null;
    }

    function calcAutoIconSize(thickness) {
        return Math.max(24, thickness > 0 ? thickness : 28);
    }

    function calcAutoFontSize(thickness) {
        var t = thickness > 0 ? thickness : 28;
        return Math.max(9, Qt.application.font.pointSize, Math.min(22, Math.round(t * 0.35)));
    }

    Keys.onSpacePressed: event => {
        if (compactRoot.timer.isRunning) {
            compactRoot.timer.togglePause();
            event.accepted = true;
        }
    }

    Keys.onLeftPressed: event => {
        compactRoot.timer.adjustUnit = "minutes";
        event.accepted = true;
    }

    Keys.onRightPressed: event => {
        compactRoot.timer.adjustUnit = "seconds";
        event.accepted = true;
    }

    Keys.onUpPressed: event => {
        compactRoot.timer.adjustTime(1, event.modifiers & Qt.ShiftModifier);
        event.accepted = true;
    }

    Keys.onDownPressed: event => {
        compactRoot.timer.adjustTime(-1, event.modifiers & Qt.ShiftModifier);
        event.accepted = true;
    }

    onClicked: mouse => {
        compactRoot.forceActiveFocus();
        if (mouse.button === Qt.LeftButton) {
            compactRoot.timer.expanded = !compactRoot.timer.expanded;
        } else if (mouse.button === Qt.MiddleButton) {
            compactRoot.timer.togglePause();
        }
    }

    onWheel: wheel => {
        compactRoot.timer.adjustTime(wheel.angleDelta.y > 0 ? 1 : -1, false);
    }

    Item {
        anchors.centerIn: parent
        width: compactRoot.iconSize
        height: compactRoot.iconSize
        visible: !compactRoot.timer.isRunning

        Kirigami.Icon {
            anchors.centerIn: parent
            width: compactRoot.iconSize
            height: compactRoot.iconSize
            source: compactRoot.effectiveIconSource
            isMask: compactRoot.effectiveTintIcon
            color: Kirigami.Theme.textColor
            smooth: true
        }
    }

    QQC2.Label {
        id: timerLabel
        anchors.centerIn: parent
        visible: compactRoot.timer.isRunning
        text: compactRoot.timer.formatTime(compactRoot.timer.remainingSeconds)
        font.family: "Noto Sans"
        font.pointSize: compactRoot.fontSize
        font.weight: Font.Normal
        color: Kirigami.Theme.textColor
    }
}
