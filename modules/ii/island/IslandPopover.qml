pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay

/**
 * Compact popover that appears below the island on left-click.
 * Shows overlay widget toggles + a shortcut to open the full overlay.
 */
Item {
    id: root

    property bool open: false

    // Sized to the pill content, positioned by Island.qml
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    opacity: open ? 1 : 0
    scale: open ? 1 : 0.88
    transformOrigin: Item.Top

    Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
        NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
    }

    // Click outside to close
    function tryClose(mx, my) {
        root.open = false
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: row.implicitWidth + 16
        implicitHeight: row.implicitHeight + 14
        color: Appearance.m3colors.m3surfaceContainerLow
        radius: Appearance.rounding.large
        border.color: "#1a1a1a"
        border.width: 1

        // Inner border — same as island style
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.width: 1
            border.color: "#1a1a1a"
            opacity: 0.4
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 4

            // Widget toggle buttons — same icons/logic as OverlayTaskbar
            Repeater {
                model: OverlayContext.availableWidgets
                delegate: WidgetToggleButton {
                    required property var modelData
                    identifier: modelData.identifier
                    symbol:     modelData.materialSymbol
                }
            }

            // Divider
            Rectangle {
                implicitWidth: 1
                implicitHeight: 28
                color: Appearance.colors.colOutlineVariant
                opacity: 0.6
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                Layout.rightMargin: 2
            }

            // Open full overlay button
            RippleButton {
                id: overlayBtn
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: implicitHeight
                implicitHeight: 36
                buttonRadius: Appearance.rounding.large - 4
                onClicked: {
                    root.open = false
                    GlobalStates.overlayOpen = true
                }
                StyledToolTip { text: "Open Overlay (Super+G)" }

                contentItem: Item {
                    anchors.centerIn: parent
                    implicitWidth: 36; implicitHeight: 36
                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 22
                        text: "open_in_full"
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }
    }

    // ── widget toggle button component ──────────────────────────────────────
    component WidgetToggleButton: RippleButton {
        id: wtb
        required property string identifier
        required property string symbol

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: implicitHeight
        implicitHeight: 36
        buttonRadius: Appearance.rounding.large - 4

        readonly property bool active: Persistent.states.overlay.open.includes(identifier)

        toggled: active

        colBackgroundToggled:      Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        colRippleToggled:          Appearance.colors.colSecondaryContainerActive

        onClicked: {
            if (wtb.active) {
                Persistent.states.overlay.open =
                    Persistent.states.overlay.open.filter(t => t !== wtb.identifier)
            } else {
                Persistent.states.overlay.open.push(wtb.identifier)
                // Make sure overlay is open so widget appears
                GlobalStates.overlayOpen = true
                root.open = false
            }
        }

        StyledToolTip {
            text: wtb.identifier
                .replace(/([A-Z])/g, " $1")
                .replace(/^./, s => s.toUpperCase())
        }

        contentItem: Item {
            anchors.centerIn: parent
            implicitWidth: 36; implicitHeight: 36
            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: 22
                text: wtb.symbol
                color: wtb.active
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnSurfaceVariant
            }
        }
    }
}
