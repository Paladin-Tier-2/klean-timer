import QtQuick
import QtCore
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: root

    property string cfg_iconType: plasmoid.configuration.iconType || "sleek-circle"
    property string cfg_customSvgPath: plasmoid.configuration.customSvgPath || ""
    property int cfg_iconSize: plasmoid.configuration.iconSize > 0 ? plasmoid.configuration.iconSize : 24
    property int cfg_timerFontSize: plasmoid.configuration.timerFontSize > 0 ? plasmoid.configuration.timerFontSize : 13
    property bool cfg_tintIcon: plasmoid.configuration.tintIcon !== undefined ? plasmoid.configuration.tintIcon : true
    property bool cfg_autoScale: plasmoid.configuration.autoScale !== undefined ? plasmoid.configuration.autoScale : true

    readonly property var presetMap: ({
        "sleek-circle": "sleek-play-circle.svg",
        "pomodoro": "pomodoro-start-light.svg",
        "frame": "pomodoro-frame-light.svg",
        "pause-circle": "sleek-pause-circle.svg"
    })

    function resolveIconUrl() {
        if (cfg_iconType === "custom" && cfg_customSvgPath) {
            var path = ("" + cfg_customSvgPath).trim();
            if (path.startsWith("file://") || path.startsWith("/")) {
                return path.startsWith("file://") ? path : "file://" + path;
            }
            return "file://" + path;
        }
        var filename = presetMap[cfg_iconType] || "sleek-play-circle.svg";
        return Qt.resolvedUrl("../icons/" + filename);
    }

    FileDialog {
        id: fileDialog
        title: i18n("Select SVG Icon")
        nameFilters: [i18n("SVG files (*.svg)")]
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        onAccepted: {
            var raw = ("" + selectedFile).trim();
            var localPath = raw.startsWith("file://") ? decodeURIComponent(raw.substring(7)) : raw;
            if (/\.svg$/i.test(localPath)) {
                root.cfg_customSvgPath = localPath;
                root.cfg_iconType = "custom";
                svgErrorMsg.visible = false;
            } else {
                svgErrorMsg.text = i18n("Only SVG files (*.svg) are supported.");
                svgErrorMsg.visible = true;
            }
        }
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        Item {
            Kirigami.FormData.label: i18n("Preview:")
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 4

            Rectangle {
                anchors.fill: parent
                color: Kirigami.Theme.alternateBackgroundColor
                radius: Kirigami.Units.smallSpacing
                border.color: Kirigami.Theme.separatorColor
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Layout.alignment: Qt.AlignHCenter

                        QQC2.Label {
                            text: i18n("Idle (Icon)")
                            font.pointSize: 9
                            color: Kirigami.Theme.disabledTextColor
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item {
                            width: root.cfg_iconSize
                            height: root.cfg_iconSize
                            Layout.alignment: Qt.AlignHCenter

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: root.cfg_iconSize
                                height: root.cfg_iconSize
                                source: root.resolveIconUrl()
                                isMask: root.cfg_tintIcon
                                color: Kirigami.Theme.textColor
                                smooth: true
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        color: Kirigami.Theme.separatorColor
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Layout.alignment: Qt.AlignHCenter

                        QQC2.Label {
                            text: i18n("Running (Digits)")
                            font.pointSize: 9
                            color: Kirigami.Theme.disabledTextColor
                            Layout.alignment: Qt.AlignHCenter
                        }

                        QQC2.Label {
                            text: "05:00"
                            font.family: "Noto Sans"
                            font.pointSize: root.cfg_timerFontSize
                            font.weight: Font.Normal
                            color: Kirigami.Theme.textColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Icon")
        }

        QQC2.ComboBox {
            id: iconPresetCombo
            Kirigami.FormData.label: i18n("Icon style:")
            Layout.fillWidth: true

            textRole: "text"
            valueRole: "value"

            model: [
                { text: i18n("Sleek Circle (Default)"), value: "sleek-circle" },
                { text: i18n("Pomodoro"), value: "pomodoro" },
                { text: i18n("Circle Frame"), value: "frame" },
                { text: i18n("Pause Circle"), value: "pause-circle" },
                { text: i18n("Custom SVG File..."), value: "custom" }
            ]

            Component.onCompleted: {
                for (var i = 0; i < model.length; ++i) {
                    if (model[i].value === root.cfg_iconType) {
                        currentIndex = i;
                        break;
                    }
                }
            }

            onActivated: {
                root.cfg_iconType = currentValue;
                if (currentValue === "custom" && !root.cfg_customSvgPath) {
                    fileDialog.open();
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Custom SVG:")
            visible: root.cfg_iconType === "custom"
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: customPathField
                Layout.fillWidth: true
                text: root.cfg_customSvgPath
                placeholderText: i18n("/path/to/custom-icon.svg")
                onEditingFinished: {
                    var trimmed = text.trim();
                    if (!trimmed || /\.svg$/i.test(trimmed)) {
                        root.cfg_customSvgPath = trimmed;
                        svgErrorMsg.visible = false;
                    } else {
                        svgErrorMsg.text = i18n("Only SVG files (*.svg) are supported.");
                        svgErrorMsg.visible = true;
                    }
                }
            }

            QQC2.Button {
                text: i18n("Browse…")
                icon.name: "document-open"
                onClicked: fileDialog.open()
            }
        }

        Kirigami.InlineMessage {
            id: svgErrorMsg
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            visible: false
            showCloseButton: true
        }

        QQC2.CheckBox {
            id: tintCheck
            Kirigami.FormData.label: i18n("Color:")
            text: i18n("Tint icon with panel text color")
            checked: root.cfg_tintIcon
            onToggled: root.cfg_tintIcon = checked
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Sizing")
        }

        QQC2.CheckBox {
            id: autoScaleCheck
            Kirigami.FormData.label: i18n("Scaling:")
            text: i18n("Scale automatically with panel thickness (Recommended)")
            checked: root.cfg_autoScale
            onToggled: root.cfg_autoScale = checked
        }

        QQC2.Label {
            visible: root.cfg_autoScale
            text: i18n("The icon and countdown size automatically adjust to your KDE panel configuration.")
            font.pointSize: 9
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Panel icon size:")
            visible: !root.cfg_autoScale
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            QQC2.Slider {
                id: iconSizeSlider
                Layout.fillWidth: true
                from: 16
                to: 48
                stepSize: 2
                value: root.cfg_iconSize
                onMoved: root.cfg_iconSize = value
            }

            QQC2.SpinBox {
                from: 16
                to: 48
                stepSize: 2
                value: root.cfg_iconSize
                editable: true
                textFromValue: (val) => val + " px"
                valueFromText: (str) => parseInt(str) || 24
                onValueModified: root.cfg_iconSize = value
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Panel countdown font size:")
            visible: !root.cfg_autoScale
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            QQC2.Slider {
                id: timerFontSlider
                Layout.fillWidth: true
                from: 9
                to: 24
                stepSize: 1
                value: root.cfg_timerFontSize
                onMoved: root.cfg_timerFontSize = value
            }

            QQC2.SpinBox {
                from: 9
                to: 24
                stepSize: 1
                value: root.cfg_timerFontSize
                editable: true
                textFromValue: (val) => val + " pt"
                valueFromText: (str) => parseInt(str) || 13
                onValueModified: root.cfg_timerFontSize = value
            }
        }
    }
}
