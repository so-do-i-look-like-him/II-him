pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common

Scope {
    id: island

    property int screenGap: 6

    // Standalone always-on-top crosshair (independent of overlay system)
    IslandCrosshair {}

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.island.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }
        LazyLoader {
            id: islandLoader
            active: !GlobalStates.screenLocked
            required property ShellScreen modelData
            component: PanelWindow {
                id: islandRoot
                screen: islandLoader.modelData

                WlrLayershell.namespace: "quickshell:island"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusiveZone: 64

                anchors { top: true; left: true; right: true }

                implicitHeight: 64
                color: "transparent"

                // Focus grab — active when popover is open.
                // Any click outside the island window fires onCleared → close popover.
                HyprlandFocusGrab {
                    id: popoverGrab
                    windows: [islandRoot]
                    active: false
                    onCleared: {
                        if (!active) islandContent.popoverOpen = false
                    }
                }

                Connections {
                    target: islandContent
                    function onPopoverOpenChanged() {
                        if (islandContent.popoverOpen) {
                            popoverGrab.active = true
                        } else {
                            popoverGrab.active = false
                        }
                    }
                }

                MouseArea {
                    id: hoverRegion
                    anchors.fill: parent
                    onClicked: islandContent.popoverOpen = false

                    IslandContent {
                        id: islandContent
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
