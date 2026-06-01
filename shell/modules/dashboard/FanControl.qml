pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    readonly property int cardWidth: 230
    readonly property int contentHeight: 300

    function hex2(n: int): string {
        const s = Math.round(n).toString(16);
        return s.length < 2 ? "0" + s : s;
    }

    implicitWidth: cardWidth * 3 + Tokens.spacing.normal * 2 + Tokens.padding.large * 2
    implicitHeight: contentHeight

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        // ── Left fan (CPU) ───────────────────────────────────
        FanCard {
            Layout.fillHeight: true
            Layout.preferredWidth: root.cardWidth
            label: qsTr("Left Fan")
            sub: qsTr("CPU")
            rpm: Casper.leftFan
        }

        // ── Centre: RGB controls + reset ─────────────────────
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: root.cardWidth
            spacing: Tokens.spacing.normal

            StyledRect {
                id: rgbCard

                property bool settingsOpen: false

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.rounding.large
                color: Casper.ledOn ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainer

                // top bar: brightness dots (left) + settings gear (right)
                RowLayout {
                    id: topBar

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Tokens.padding.normal
                    anchors.topMargin: Tokens.padding.smaller
                    spacing: Tokens.spacing.small

                    RowLayout {
                        spacing: Tokens.spacing.small / 2
                        visible: !rgbCard.settingsOpen

                        // ordered left->right as brightness 2,1,0 (power grows right->left)
                        BrightDot {
                            level: 2
                        }
                        BrightDot {
                            level: 1
                        }
                        BrightDot {
                            level: 0
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledRect {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Tokens.rounding.full
                        color: "transparent"

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onSurface
                            onClicked: rgbCard.settingsOpen = !rgbCard.settingsOpen
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: rgbCard.settingsOpen ? "close" : "settings"
                            color: Casper.ledOn ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.large
                        }
                    }
                }

                // ── default view: keyboard + switch ──────────
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.large * 2
                    spacing: Tokens.spacing.normal
                    visible: !rgbCard.settingsOpen

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: Casper.ledOn ? "keyboard" : "keyboard_off"
                        fill: Casper.ledOn ? 1 : 0
                        color: Casper.ledOn ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.extraLarge * 1.7

                        Behavior on fill {
                            Anim {}
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Keyboard RGB")
                        color: Casper.ledOn ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.normal
                        font.weight: 500
                    }

                    StyledSwitch {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.spacing.small
                        scale: 1.3
                        checked: Casper.ledOn
                        onToggled: Casper.setOn(checked)
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.spacing.small
                        text: Casper.ledOn ? qsTr("On · power %1/2").arg(Casper.brightness) : qsTr("Off")
                        color: Casper.ledOn ? Colours.palette.m3primary : Colours.palette.m3outline
                        font.pointSize: Tokens.font.size.small
                    }
                }

                // ── settings view: colour picker ─────────────
                ColumnLayout {
                    id: picker

                    function loadFromHex(hex: string): void {
                        rSlider.value = parseInt(hex.substr(0, 2), 16);
                        gSlider.value = parseInt(hex.substr(2, 2), 16);
                        bSlider.value = parseInt(hex.substr(4, 2), 16);
                    }
                    function pushColor(): void {
                        Casper.setColor(root.hex2(rSlider.value) + root.hex2(gSlider.value) + root.hex2(bSlider.value));
                    }

                    anchors.top: topBar.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.padding.large
                    anchors.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small
                    visible: rgbCard.settingsOpen

                    Component.onCompleted: loadFromHex(Casper.colorHex)

                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Tokens.rounding.normal
                        color: "#" + Casper.colorHex
                        border.width: 1
                        border.color: Colours.palette.m3outlineVariant
                    }

                    ColorSlider {
                        id: rSlider
                        tint: "#ff5555"
                    }
                    ColorSlider {
                        id: gSlider
                        tint: "#55ff55"
                    }
                    ColorSlider {
                        id: bSlider
                        tint: "#5599ff"
                    }

                    GridLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.spacing.small
                        columns: 5
                        rowSpacing: Tokens.spacing.small
                        columnSpacing: Tokens.spacing.small

                        Repeater {
                            model: ["ffffff", "ff0000", "ff7f00", "ffff00", "00ff00", "00ffff", "0088ff", "0000ff", "8800ff", "ff00ff"]

                            Swatch {
                                required property string modelData
                                hex: modelData
                            }
                        }
                    }
                }
            }

            // Reset button (hidden while the colour picker is open)
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                visible: !rgbCard.settingsOpen
                radius: Tokens.rounding.normal
                color: Colours.tPalette.m3surfaceContainerHigh

                StateLayer {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    radius: parent.radius
                    color: Colours.palette.m3error

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            Casper.hardReset();
                        else
                            Casper.softReset();
                    }
                    onPressAndHold: Casper.hardReset()
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "restart_alt"
                        color: Colours.palette.m3error
                        font.pointSize: Tokens.font.size.large

                        RotationAnimation on rotation {
                            running: Casper.resetting
                            from: 0
                            to: 360
                            duration: 600
                            loops: Animation.Infinite
                        }
                    }

                    ColumnLayout {
                        spacing: 0

                        StyledText {
                            text: qsTr("Reset")
                            color: Colours.palette.m3onSurface
                            font.pointSize: Tokens.font.size.small
                        }
                        StyledText {
                            text: qsTr("right-click: full reset")
                            color: Colours.palette.m3outline
                            font.pointSize: Tokens.font.size.small
                        }
                    }
                }
            }
        }

        // ── Right fan (GPU) ──────────────────────────────────
        FanCard {
            Layout.fillHeight: true
            Layout.preferredWidth: root.cardWidth
            label: qsTr("Right Fan")
            sub: qsTr("GPU")
            rpm: Casper.rightFan
        }
    }

    // 3-level brightness dot (a level meter that fills right->left)
    component BrightDot: StyledRect {
        required property int level
        readonly property bool on: Casper.ledOn && Casper.brightness >= level

        implicitWidth: 14
        implicitHeight: 14
        radius: Tokens.rounding.full
        color: on ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

        StateLayer {
            radius: parent.radius
            color: Colours.palette.m3onSurface
            onClicked: Casper.setBrightness(parent.level)
        }
    }

    component ColorSlider: StyledSlider {
        required property color tint

        Layout.fillWidth: true
        implicitHeight: 18
        from: 0
        to: 255
        onMoved: picker.pushColor()
    }

    component Swatch: StyledRect {
        required property string hex

        implicitWidth: 26
        implicitHeight: 26
        radius: Tokens.rounding.full
        color: "#" + hex
        border.width: Casper.colorHex === hex ? 2 : 1
        border.color: Casper.colorHex === hex ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

        StateLayer {
            radius: parent.radius
            onClicked: {
                Casper.setColor(parent.hex);
                picker.loadFromHex(parent.hex);
            }
        }
    }

    component FanCard: StyledRect {
        id: card

        property string label
        property string sub
        property int rpm

        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Tokens.padding.large * 2
            spacing: Tokens.spacing.small

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "mode_fan"
                fill: 1
                color: card.rpm > 0 ? Colours.palette.m3primary : Colours.palette.m3outline
                font.pointSize: Tokens.font.size.extraLarge * 1.9

                RotationAnimator on rotation {
                    running: card.rpm > 0
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: card.rpm > 0 ? Math.max(250, 90000 / card.rpm) : 1000
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.small
                text: Casper.available ? card.rpm : "—"
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.extraLarge * 1.15
                font.weight: 600
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Casper.available ? "RPM" : qsTr("no sensor")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.small
                text: card.label
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.normal
                font.weight: 500
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: card.sub
                color: Colours.palette.m3outline
                font.pointSize: Tokens.font.size.small
            }
        }
    }
}
