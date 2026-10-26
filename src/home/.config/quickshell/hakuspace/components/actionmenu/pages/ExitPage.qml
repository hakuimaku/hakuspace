import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Exit Session"
    subtitle: "Active processes will be terminated"
    icon: "󰍃"
    geometryProfile: "exitReport"

    property bool fromPower: false
    property var processItems: []
    property string rawReport: ""
    property int selectedActionIndex: 0 // 0: Cancel, 1: Exit Anyway
    property bool exiting: false

    property var _pendingItems: []

    Process {
        id: reportProc
        command: [Env.binDir + "/session_exit_ctl.sh", "process-report"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                var parts = line.split("|");
                if (parts.length >= 3) {
                    var comm = parts[0].replace("•", "").trim();
                    var pids = parts[1].trim().replace(/\s+/g, " ");
                    var rest = parts[2].trim();
                    var isHighRam = rest.indexOf("[HIGH RAM]") !== -1;
                    var ram = rest.replace("[HIGH RAM]", "").replace("[Active]", "").trim().replace(/\s+/g, " ");
                    root._pendingItems.push({
                        comm: comm,
                        pids: pids,
                        ram: ram,
                        highRam: isHighRam
                    });
                }
            }
        }
        onExited: {
            root.processItems = root._pendingItems.slice();
        }
    }

    Process {
        id: prepareExitProc
        onExited: (exitCode, exitStatus) => {
            if (!root.exiting) return;

            // The active Hikai WM backend already owns a proven-live compositor
            // IPC connection. Let it deliver the quit request while Quickshell is
            // still alive instead of asking a teardown script to rediscover IPC.
            if (exitCode === 0 && WM.quitSession()) {
                root.requestClose();
                return;
            }

            // Defensive fallback for an unsupported/failed backend. This keeps
            // the old headless path available instead of leaving the UI stuck.
            Quickshell.execDetached([Env.binDir + "/session_exit_ctl.sh", "execute"]);
            root.requestClose();
        }
    }

    // Aborts session termination and returns to previous menu or closes layer.
    function doCancel() {
        if (root.canGoBack) {
            root.requestBack();
        } else {
            root.requestClose();
        }
    }

    // Prepares the Hikai session, then asks the active WM backend to quit.
    function doExit() {
        if (root.exiting) return;
        root.exiting = true;
        prepareExitProc.command = [Env.binDir + "/session_exit_ctl.sh", "prepare-hikai"];
        prepareExitProc.running = true;
    }

    onScrollPrevious: {
        root.selectedActionIndex = Math.max(0, root.selectedActionIndex - 1);
    }

    onScrollNext: {
        root.selectedActionIndex = Math.min(1, root.selectedActionIndex + 1);
    }

    Keys.onLeftPressed: event => {
        root.selectedActionIndex = Math.max(0, root.selectedActionIndex - 1);
        event.accepted = true;
    }

    Keys.onRightPressed: event => {
        root.selectedActionIndex = Math.min(1, root.selectedActionIndex + 1);
        event.accepted = true;
    }

    Keys.onTabPressed: event => {
        root.selectedActionIndex = Math.min(1, root.selectedActionIndex + 1);
        event.accepted = true;
    }

    Keys.onBacktabPressed: event => {
        root.selectedActionIndex = Math.max(0, root.selectedActionIndex - 1);
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.selectedActionIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selectedActionIndex = 1;
            event.accepted = true;
        }
    }

    // Triggers execution or cancellation depending on selected button index.
    function activateCurrent() {
        if (root.selectedActionIndex === 1) doExit();
        else doCancel();
    }

    Keys.onReturnPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    Keys.onEnterPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.pad

        // Process report table header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: 6
            color: Qt.alpha(Theme.overlayInk, 0.04)

            Item {
                id: headerCols
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad

                readonly property real colAppWidth: Math.floor(width * 0.50)
                readonly property real colInstWidth: Math.floor(width * 0.25)
                readonly property real colMemWidth: width - colAppWidth - colInstWidth

                Text {
                    x: 0
                    width: parent.colAppWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Application"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.fgMuted
                    elide: Text.ElideRight
                }

                Text {
                    x: parent.colAppWidth
                    width: parent.colInstWidth
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "Instances"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.fgMuted
                }

                Text {
                    x: parent.colAppWidth + parent.colInstWidth
                    width: parent.colMemWidth
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: "Memory"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.fgMuted
                }
            }
        }

        // Scrollable process report
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius
            color: Qt.rgba(0, 0, 0, 0.25)
            clip: true

            Text {
                visible: reportProc.running && root.processItems.length === 0
                anchors.centerIn: parent
                text: "Scanning active processes..."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fgMuted
            }

            ListView {
                id: processList
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2
                clip: true
                model: root.processItems

                ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                    id: vbar
                }

                delegate: Rectangle {
                    width: processList.width - vbar.reservedGutter
                    height: Math.max(32, Theme.fontSize * 2.0)
                    radius: 4
                    color: index % 2 === 0 ? "transparent" : Qt.alpha(Theme.overlayInk, 0.02)

                    Item {
                        id: rowCols
                        anchors.fill: parent
                        anchors.leftMargin: Theme.pad
                        anchors.rightMargin: Theme.pad

                        readonly property real colAppWidth: Math.floor(width * 0.50)
                        readonly property real colInstWidth: Math.floor(width * 0.25)
                        readonly property real colMemWidth: width - colAppWidth - colInstWidth

                        Text {
                            x: 0
                            width: parent.colAppWidth
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.comm
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 1
                            font.weight: modelData.highRam ? Font.DemiBold : Font.Normal
                            color: modelData.highRam ? Theme.danger : Theme.fg
                            elide: Text.ElideRight
                        }

                        Text {
                            x: parent.colAppWidth
                            width: parent.colInstWidth
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.pids
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(9, Math.round((Theme.fontSize + 1) * 0.82))
                            color: Theme.fgMuted
                        }

                        Item {
                            x: parent.colAppWidth + parent.colInstWidth
                            width: parent.colMemWidth
                            height: parent.height

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.ram
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.max(9, Math.round((Theme.fontSize + 1) * 0.82))
                                    color: modelData.highRam ? Theme.danger : Theme.fgDim
                                }

                                Rectangle {
                                    visible: modelData.highRam
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: 6
                                    implicitHeight: 6
                                    radius: 3
                                    color: Theme.danger
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom Action buttons
        RowLayout {
            id: bottomRow
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(42, Theme.fontSize * 2.6)
            spacing: Theme.pad

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                z: -1
                targetItem: root.selectedActionIndex === 1 ? exitBtn : cancelBtn
                parent: root.contentItem
                coordinateSpace: root.contentItem
            }

            Item { Layout.fillWidth: true }

            ActionMenu.ActionMenuButton {
                id: cancelBtn
                z: 1
                Layout.preferredWidth: 130
                Layout.preferredHeight: Math.max(38, Theme.fontSize * 2.4)
                radius: Theme.radius
                selected: root.selectedActionIndex === 0
                focused: selected
                selectedOverridesHover: true

                idleColor: (selected || focused) ? "transparent" : Theme.surfaceSubtle(1.18)
                hoverColor: (selected || focused) ? "transparent" : Theme.surfaceSubtle(1.35)
                pressedColor: (selected || focused) ? "transparent" : Theme.surfaceSubtle(1.55)
                selectedColor: "transparent"
                focusColor: "transparent"

                foregroundColor: (selected || focused) ? Theme.onAccentColor : Theme.fg
                hoverForegroundColor: (selected || focused) ? Theme.onAccentColor : Theme.fg
                selectedForegroundColor: Theme.onAccentColor

                label: "Cancel"
                onPointerSelected: {
                    if (hovered) {
                        root.selectedActionIndex = 0;
                    }
                }
                onClicked: {
                    root.selectedActionIndex = 0;
                    doCancel();
                }
            }

            ActionMenu.ActionMenuButton {
                id: exitBtn
                z: 1
                danger: true
                Layout.preferredWidth: 150
                Layout.preferredHeight: Math.max(38, Theme.fontSize * 2.4)
                radius: Theme.radius
                selected: root.selectedActionIndex === 1
                focused: selected
                selectedOverridesHover: true

                idleColor: (selected || focused) ? "transparent" : Qt.rgba(1.0, 0.3, 0.3, 0.15)
                hoverColor: (selected || focused) ? "transparent" : Qt.rgba(1.0, 0.3, 0.3, 0.35)
                pressedColor: (selected || focused) ? "transparent" : Qt.rgba(1.0, 0.3, 0.3, 0.5)
                selectedColor: "transparent"
                focusColor: "transparent"

                foregroundColor: (selected || focused) ? "#ffffff" : Theme.danger
                hoverForegroundColor: "#ffffff"
                selectedForegroundColor: "#ffffff"

                label: "Exit Anyway"
                onPointerSelected: {
                    if (hovered) {
                        root.selectedActionIndex = 1;
                    }
                }
                onClicked: {
                    root.selectedActionIndex = 1;
                    doExit();
                }
            }
        }
    }
}
