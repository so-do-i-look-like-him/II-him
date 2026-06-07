import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope

    // Fade animation: 0 = transparent, 1 = opaque. Driven explicitly from
    // Connections so the Behavior fires reliably. Used for both open (0 → 1)
    // and close (1 → 0); the PanelWindow stays alive during close via the
    // isClosing flag + closeResetTimer below.
    property real fadeProgress: 0
    // Keep the PanelWindow mounted while the close fade plays out.
    property bool isClosing: false

    Behavior on fadeProgress {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    // Slide offset for close animation: 0 = resting, positive = slid down
    property real slideOffset: 300
    Behavior on slideOffset {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        // Slightly longer than the fade duration so the PanelWindow is
        // guaranteed visible for the full fade-out before it disappears.
        id: closeResetTimer
        interval: 460
        repeat: false
        onTriggered: overviewScope.isClosing = false
    }

    // If the panel is open at QML startup, sync fadeProgress = 1.
    Component.onCompleted: {
        if (GlobalStates.overviewOpen) {
            overviewScope.fadeProgress = 1;
            overviewScope.slideOffset = 0;
        }
    }

    PanelWindow {
        id: panelWindow
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        // Keep the PanelWindow alive during the close fade-out.
        visible: GlobalStates.overviewOpen || overviewScope.isClosing

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: GlobalStates.overviewOpen ? columnLayout : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!GlobalStates.overviewOpen) {
                    GlobalFocusGrab.dismiss();
                    // Start the close fade-out. fadeProgress animates 1 → 0 via
                    // its Behavior; isClosing keeps the PanelWindow mounted
                    // until closeResetTimer fires.
                    overviewScope.isClosing = true;
                    overviewScope.fadeProgress = 0;
                    overviewScope.slideOffset = 300;
                    closeResetTimer.restart();
                } else {
                    // Cancel any in-flight close reset, then start the open fade.
                    closeResetTimer.stop();
                    overviewScope.isClosing = false;
                    overviewScope.fadeProgress = 1;
                    overviewScope.slideOffset = 0;
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.overviewOpen = false;
            }
        }
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        Column {
            id: columnLayout
            // Stay mounted while the close fade plays; only hide once fully transparent.
            visible: opacity > 0.001
            opacity: overviewScope.fadeProgress
            transform: Translate {
                y: overviewScope.slideOffset
            }
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            topPadding: 180
            spacing: 0

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                }
            }

            OverviewWidget {
                anchors.horizontalCenter: parent.horizontalCenter
                screen: panelWindow.screen
            }
        }
    }

    IpcHandler {
        target: "overview"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
    }

    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
            if (GlobalStates.overviewOpen)
                GlobalStates.searchOpen = false;
        }
    }
}
