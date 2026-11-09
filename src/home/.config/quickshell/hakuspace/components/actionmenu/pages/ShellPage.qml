import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: phase === "password" ? "Authentication Required" : (phase === "restart" ? "Restart Session" : "Change Shell")
    subtitle: phase === "password" ? "Enter sudo password to change login shell" : (phase === "restart" ? "Shell changed to " + targetShell + ". Apply now?" : "Choose default login shell")
    icon: ""
    geometryProfile: "option"
    canGoBack: phase === "password"

    property string phase: "select" // "select" | "password" | "restart"
    property var shells: []
    property string currentShell: ""
    property string targetShell: ""
    property int selectedIndex: 0
    property int selectedRestartIndex: 0
    property bool loading: true
    property string statusMessage: ""
    property string passwordError: ""

    onRequestBack: {
        if (phase === "password") {
            phase = "select";
            passwordError = "";
            statusMessage = "";
        } else {
            root.requestClose();
        }
    }

    Process {
        id: currentProc
        command: [Env.binDir + "/shell_ctl.sh", "current"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var c = data.trim();
                if (c) {
                    var parts = c.split("/");
                    root.currentShell = parts[parts.length - 1];
                }
            }
        }
    }

    Process {
        id: listProc
        command: [Env.binDir + "/shell_ctl.sh", "list", "--json"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var jsonStr = data.trim();
                if (!jsonStr) return;
                try {
                    var items = JSON.parse(jsonStr);
                    root.shells = items || [];
                    for (var i = 0; i < root.shells.length; i++) {
                        if (root.shells[i].current) {
                            root.selectedIndex = i;
                            break;
                        }
                    }
                } catch (e) {
                }
            }
        }
        onExited: {
            if (root.shells.length === 0) {
                root.shells = [
                    { id: "fish", path: "/usr/bin/fish", current: root.currentShell === "fish" },
                    { id: "zsh", path: "/bin/zsh", current: root.currentShell === "zsh" }
                ];
            }
            root.loading = false;
        }
    }

    Process {
        id: setProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.phase = "restart";
                root.selectedRestartIndex = 0;
            } else if (exitCode === 77) {
                root.phase = "password";
                root.passwordError = "";
                Qt.callLater(function() {
                    passwordInput.text = "";
                    passwordInput.forceActiveFocus();
                });
            } else {
                root.statusMessage = "Failed to change shell (code " + exitCode + ")";
            }
        }
    }

    Process {
        id: pwSetProc
        onExited: (exitCode, exitStatus) => {
            environment = ({});
            if (exitCode === 0) {
                passwordInput.text = "";
                root.phase = "restart";
                root.selectedRestartIndex = 0;
            } else if (exitCode === 77) {
                root.passwordError = "Incorrect password. Please try again.";
                passwordInput.text = "";
                passwordInput.forceActiveFocus();
            } else {
                root.passwordError = "Authentication failed (code " + exitCode + ")";
                passwordInput.text = "";
            }
        }
    }

    function applyShell(shellId) {
        if (!shellId) return;
        if (shellId === root.currentShell) {
            root.requestClose();
            return;
        }
        root.targetShell = shellId;
        root.statusMessage = "";
        setProc.command = [Env.binDir + "/shell_ctl.sh", "set", shellId];
        setProc.running = true;
    }

    function submitPassword() {
        var pw = passwordInput.text;
        if (!pw) return;
        root.passwordError = "";
        pwSetProc.environment = { "HAKUSPACE_SUDO_PW": pw };
        pwSetProc.command = ["sh", "-c", "printf '%s\\n' \"$HAKUSPACE_SUDO_PW\" | HAKUSPACE_SUDO_STDIN=1 \"$1\" set \"$2\"", "_", Env.binDir + "/shell_ctl.sh", root.targetShell];
        pwSetProc.running = true;
    }

    function activateCurrent() {
        if (phase === "select") {
            if (root.shells.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.shells.length) {
                applyShell(root.shells[root.selectedIndex].id);
            }
        } else if (phase === "password") {
            submitPassword();
        } else if (phase === "restart") {
            triggerRestartOption(root.selectedRestartIndex);
        }
    }

    function triggerRestartOption(idx) {
        switch (idx) {
        case 0: // Log out
            if (WM.quitSession()) {
                root.requestClose();
                return;
            }
            Quickshell.execDetached([Env.binDir + "/session_exit_ctl.sh", "execute"]);
            root.requestClose();
            break;
        case 1: // Reboot
            Quickshell.execDetached(["systemctl", "reboot"]);
            root.requestClose();
            break;
        case 2: // Later
            root.requestClose();
            break;
        }
    }

    onScrollPrevious: {
        if (phase === "select" && shells.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            shellsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        } else if (phase === "restart") {
            root.selectedRestartIndex = Math.max(0, root.selectedRestartIndex - 1);
        }
    }

    onScrollNext: {
        if (phase === "select" && shells.length > 0) {
            root.selectedIndex = Math.min(shells.length - 1, root.selectedIndex + 1);
            shellsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        } else if (phase === "restart") {
            root.selectedRestartIndex = Math.min(2, root.selectedRestartIndex + 1);
        }
    }

    Keys.onUpPressed: event => {
        if (phase === "select" && shells.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            shellsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        } else if (phase === "restart") {
            root.selectedRestartIndex = Math.max(0, root.selectedRestartIndex - 1);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (phase === "select" && shells.length > 0) {
            root.selectedIndex = Math.min(shells.length - 1, root.selectedIndex + 1);
            shellsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        } else if (phase === "restart") {
            root.selectedRestartIndex = Math.min(2, root.selectedRestartIndex + 1);
            event.accepted = true;
        }
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

        Text {
            visible: root.statusMessage.length > 0
            text: root.statusMessage
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.warning
            Layout.alignment: Qt.AlignHCenter
        }

        // ==================== PHASE 1: SELECT SHELL ====================
        ListView {
            id: shellsList
            visible: root.phase === "select"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.shells

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: shellsList.contentItem
                z: 0
            }

            ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                id: vbar
            }

            delegate: ActionMenu.ActionMenuButton {
                id: delegateBtn
                z: 1
                width: shellsList.width - vbar.reservedGutter
                icon: modelData.id === "fish" ? "󰈺" : (modelData.id === "zsh" ? "" : "")
                label: modelData.id
                secondaryText: modelData.current || modelData.id === root.currentShell ? "Active" : ""
                badge: modelData.path || ""
                badgeColor: Theme.fgMuted
                selected: root.selectedIndex === index
                focused: selected

                Component.onCompleted: {
                    if (selected) selectionPill.targetItem = this;
                }
                onSelectedChanged: {
                    if (selected) selectionPill.targetItem = this;
                }
                onPointerSelected: {
                    if (hovered) {
                        root.selectedIndex = index;
                    }
                }
                onClicked: {
                    root.selectedIndex = index;
                    applyShell(modelData.id);
                }
            }
        }

        // ==================== PHASE 2: PASSWORD PROMPT ====================
        ColumnLayout {
            visible: root.phase === "password"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.pad * 1.5

            Item { Layout.fillHeight: true }

            Text {
                text: "Root authorization required to change shell to " + root.targetShell
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                visible: root.passwordError.length > 0
                text: root.passwordError
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                color: Theme.danger
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(42, Theme.fontSize * 2.6)
                color: Theme.surfaceSubtle(1.18)
                radius: Theme.radius
                border.color: passwordInput.activeFocus ? Theme.accent : Theme.border
                border.width: Theme.borderWidth

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.margins: Theme.pad
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    echoMode: TextInput.Password
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Enter sudo password..."
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: Theme.fgMuted
                        visible: !passwordInput.text && !passwordInput.activeFocus
                    }

                    Keys.onReturnPressed: submitPassword()
                    Keys.onEnterPressed: submitPassword()
                    Keys.onEscapePressed: {
                        root.phase = "select";
                        root.passwordError = "";
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.pad

                Item { Layout.fillWidth: true }

                ActionMenu.ActionMenuButton {
                    label: "Cancel"
                    Layout.preferredWidth: 120
                    onClicked: {
                        root.phase = "select";
                        root.passwordError = "";
                    }
                }

                ActionMenu.ActionMenuButton {
                    label: "Confirm"
                    badge: "Enter"
                    Layout.preferredWidth: 140
                    selected: true
                    focused: true
                    onClicked: submitPassword()
                }

                Item { Layout.fillWidth: true }
            }

            Item { Layout.fillHeight: true }
        }

        // ==================== PHASE 3: RESTART SESSION ====================
        ColumnLayout {
            visible: root.phase === "restart"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spaceSm

            ActionMenu.ActionMenuSelectionPill {
                id: restartPill
                z: 0
            }

            ActionMenu.ActionMenuButton {
                id: logoutBtn
                z: 1
                Layout.fillWidth: true
                icon: "󰩈"
                label: "Log out"
                secondaryText: "Terminate session to apply shell"
                badge: "Recommended"
                selected: root.selectedRestartIndex === 0
                focused: selected
                Component.onCompleted: {
                    if (selected) restartPill.targetItem = this;
                }
                onSelectedChanged: {
                    if (selected) restartPill.targetItem = this;
                }
                onPointerSelected: {
                    if (hovered) root.selectedRestartIndex = 0;
                }
                onClicked: triggerRestartOption(0)
            }

            ActionMenu.ActionMenuButton {
                id: rebootBtn
                z: 1
                Layout.fillWidth: true
                icon: ""
                label: "Reboot"
                secondaryText: "Restart the system"
                selected: root.selectedRestartIndex === 1
                focused: selected
                onSelectedChanged: {
                    if (selected) restartPill.targetItem = this;
                }
                onPointerSelected: {
                    if (hovered) root.selectedRestartIndex = 1;
                }
                onClicked: triggerRestartOption(1)
            }

            ActionMenu.ActionMenuButton {
                id: laterBtn
                z: 1
                Layout.fillWidth: true
                icon: "󰅖"
                label: "Later"
                secondaryText: "Keep working, apply on next login"
                selected: root.selectedRestartIndex === 2
                focused: selected
                onSelectedChanged: {
                    if (selected) restartPill.targetItem = this;
                }
                onPointerSelected: {
                    if (hovered) root.selectedRestartIndex = 2;
                }
                onClicked: triggerRestartOption(2)
            }
        }
    }
}
