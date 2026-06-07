import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overview
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: searchScope
    property bool dontAutoCancelSearch: false

    // Fade animation: 0 = transparent, 1 = opaque
    property real fadeProgress: 0
    property bool isClosing: false

    Behavior on fadeProgress {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    property real slideOffset: 300
    Behavior on slideOffset {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: closeResetTimer
        interval: 460
        repeat: false
        onTriggered: searchScope.isClosing = false
    }

    Component.onCompleted: {
        if (GlobalStates.searchOpen) {
            searchScope.fadeProgress = 1;
            searchScope.slideOffset = 0;
        }
    }

    PanelWindow {
        id: panelWindow
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        visible: GlobalStates.searchOpen || searchScope.isClosing

        WlrLayershell.namespace: "quickshell:search"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.searchOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: GlobalStates.searchOpen ? columnLayout : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: GlobalStates
            function onSearchOpenChanged() {
                if (!GlobalStates.searchOpen) {
                    searchWidget.disableExpandAnimation();
                    searchScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                    searchScope.isClosing = true;
                    searchScope.fadeProgress = 0;
                    searchScope.slideOffset = 300;
                    closeResetTimer.restart();
                } else {
                    closeResetTimer.stop();
                    searchScope.isClosing = false;
                    searchScope.fadeProgress = 1;
                    searchScope.slideOffset = 0;
                    if (!searchScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.searchOpen = false;
            }
        }

        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        Column {
            id: columnLayout
            visible: opacity > 0.001
            opacity: searchScope.fadeProgress
            transform: Translate {
                y: searchScope.slideOffset
            }
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            topPadding: 300
            spacing: -8

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.searchOpen = false;
                }
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter
                useLayer: searchScope.fadeProgress >= 0.99
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.searchOpen && searchScope.dontAutoCancelSearch) {
            GlobalStates.searchOpen = false;
            return;
        }
        searchScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.searchOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.searchOpen && searchScope.dontAutoCancelSearch) {
            GlobalStates.searchOpen = false;
            return;
        }
        searchScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.searchOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.searchOpen = !GlobalStates.searchOpen;
        }
        function close() {
            GlobalStates.searchOpen = false;
        }
        function open() {
            GlobalStates.searchOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            searchScope.toggleClipboard();
        }
    }

    // ---- GlobalShortcuts ----

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.searchOpen = !GlobalStates.searchOpen;
            if (GlobalStates.searchOpen)
                GlobalStates.overviewOpen = false;
        }
    }

    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.searchOpen = !GlobalStates.searchOpen;
            if (GlobalStates.searchOpen)
                GlobalStates.overviewOpen = false;
        }
    }

    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }

    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on search widget"

        onPressed: {
            searchScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on search widget"

        onPressed: {
            searchScope.toggleEmojis();
        }
    }
}
