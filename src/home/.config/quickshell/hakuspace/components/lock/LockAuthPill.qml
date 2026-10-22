import QtQuick
import "../../services"

Item {
    id: root

    required property var pillGeo
    property color pillColor: Theme.accent
    property color pillTextColor: Theme.onAccentColor
    property color submitBgColor: Theme.onAccentColor
    property color submitFgColor: Theme.accent
    property bool interactive: true

    property string passwordBuffer: ""
    readonly property bool inputFocused: focusArea.activeFocus
    readonly property bool busy: LockState.authState === "Authenticating" || LockState.authState === "Success"

    signal keystrokeTyped()

    width: pillGeo.width
    height: pillGeo.height
    scale: pillGeo.scale

    function clearInput() {
        root.passwordBuffer = ""
    }

    function focusInput() {
        if (!root.interactive || root.busy) return
        focusArea.forceActiveFocus()
    }

    function submitCurrentInput() {
        if (!root.interactive || root.busy) return
        if (root.passwordBuffer.length === 0) return
        var submitted = root.passwordBuffer
        root.passwordBuffer = ""
        LockState.submit(submitted)
        submitted = ""
    }

    Connections {
        target: LockState
        function onClearInputRequested() {
            root.clearInput()
        }
        function onRefocusInputRequested() {
            if (root.interactive) {
                root.focusInput()
            }
        }
    }

    Item {
        id: focusArea
        anchors.fill: parent
        focus: root.interactive
        activeFocusOnTab: root.interactive
        enabled: root.interactive && !root.busy

        Keys.onPressed: event => {
            if (!root.interactive || root.busy) return
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.submitCurrentInput()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                // Security invariant: Escape never unlocks the session.
                root.passwordBuffer = ""
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (root.passwordBuffer.length > 0) {
                    root.passwordBuffer = root.passwordBuffer.slice(0, -1)
                    LockState.noteUserInput()
                    root.keystrokeTyped()
                }
                event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_U) {
                root.passwordBuffer = ""
                event.accepted = true
            } else if (event.text && event.text.length > 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                var code = event.text.charCodeAt(0)
                if (code >= 32 && code !== 127) {
                    root.passwordBuffer += event.text
                    LockState.noteUserInput()
                    root.keystrokeTyped()
                    event.accepted = true
                }
            }
        }
    }

    Rectangle {
        id: capsule
        anchors.fill: parent
        radius: root.pillGeo.radius
        color: root.pillColor
        visible: root.pillGeo.visible
        antialiasing: true

        MouseArea {
            anchors.fill: parent
            enabled: root.interactive
            onClicked: root.focusInput()
        }

        // Symmetric submit clearance keeps large password dots centered in the capsule.
        Item {
            anchors.left: parent.left
            anchors.leftMargin: root.pillGeo.submitSize + Theme.pad + Theme.gap
            anchors.right: parent.right
            anchors.rightMargin: root.pillGeo.submitSize + Theme.pad + Theme.gap
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            opacity: root.pillGeo.inputOpacity
            clip: true

            // Geometric dots remove the built-in spacing of font glyphs.
            Row {
                id: maskedDots
                width: implicitWidth
                x: width <= parent.width ? (parent.width - width) * 0.5 : parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(root.pillGeo.height * 0.08)

                Repeater {
                    model: root.passwordBuffer.length
                    Rectangle {
                        width: Math.round(root.pillGeo.height * 0.36)
                        height: width
                        radius: width * 0.5
                        color: root.pillTextColor
                        antialiasing: true
                    }
                }
            }
        }

        // Circular submit blob separating from the liquid capsule edge
        Rectangle {
            id: submitCircle
            x: root.pillGeo.submitX
            y: root.pillGeo.submitY
            width: root.pillGeo.submitSize
            height: root.pillGeo.submitSize
            radius: width * 0.5
            scale: root.pillGeo.submitScale
            visible: root.pillGeo.submitVisible
            color: root.submitBgColor
            antialiasing: true

            Text {
                anchors.centerIn: parent
                text: "↗"
                color: root.submitFgColor
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(parent.width * 0.43)
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.interactive && !root.busy
                onClicked: {
                    root.focusInput()
                    root.submitCurrentInput()
                }
            }
        }
    }
}
