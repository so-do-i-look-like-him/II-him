import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common

/**
 * Standalone crosshair — always centered, WlrLayer.Overlay so it renders
 * above fullscreen windows. Toggled by GlobalStates.crosshairOpen.
 */
Scope {
    Loader {
        active: GlobalStates.crosshairOpen
        sourceComponent: PanelWindow {
            id: xhairWindow
            WlrLayershell.namespace: "quickshell:island-crosshair"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }

            // Tiny input mask — no clicks pass through to this window
            mask: Region {}

            // The crosshair — always dead-center
            Item {
                anchors.centerIn: parent
                width: 20; height: 20

                // Horizontal bar
                Rectangle {
                    color: "#e53935"
                    width: 20; height: 2
                    anchors.centerIn: parent
                }
                // Vertical bar
                Rectangle {
                    color: "#e53935"
                    width: 2; height: 20
                    anchors.centerIn: parent
                }
                // Center dot
                Rectangle {
                    color: "#e53935"
                    width: 4; height: 4
                    radius: 2
                    anchors.centerIn: parent
                }
            }
        }
    }
}
