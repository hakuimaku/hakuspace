import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

// P3 Settings Stub Layer (T2)
// Standalone modal surface centered in the output.
// Visual stub with restrained modal backdrop and subtle body outline.
PanelWindow {
    id: root
    required property var modelData

    readonly property bool panelOpen: UiState.activePanel === "settings"
                                      && UiState.settingsScreenName === modelData.name

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-settings"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen

    mask: Region {
        width: root.panelOpen ? root.modelData.width : 0
        height: root.panelOpen ? root.modelData.height : 0
    }

    Component.onDestruction: UiState.closeSettingsIfScreen(modelData.name)

    onPanelOpenChanged: {
        if (panelOpen) {
            Qt.callLater(function() {
                if (root.panelOpen) keyHandler.forceActiveFocus()
            })
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.panelOpen
        Keys.onEscapePressed: event => {
            UiState.closeSettings()
            event.accepted = true
        }
    }

    // Dim modal backdrop behind Settings body
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.22
    }

    // Outside-dismiss layer: clicking outside the centered body closes Settings
    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        enabled: root.panelOpen
        acceptedButtons: Qt.LeftButton
        onClicked: UiState.closeSettings()
    }

    // Centered rounded Settings surface
    Rectangle {
        id: settingsBody
        anchors.centerIn: parent
        width: Math.round(root.modelData.width * 0.76)
        height: Math.round(root.modelData.height * 0.60)
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.border
        border.width: Theme.borderWidth

        // Subtle 1 px body outline for dark backgrounds
        Rectangle {
            id: bodyOutline
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.fg
            opacity: 0.12
        }

        // Pointer absorber: prevents clicks inside the body from reaching outsideDismiss
        MouseArea {
            id: bodyAbsorber
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: mouse => mouse.accepted = true
        }

        // Visual stub header/control: "Setting"
        Rectangle {
            id: headerControl
            x: Theme.pad * 2
            y: Theme.pad * 2
            width: Math.max(140, headerText.implicitWidth + Theme.pad * 4)
            height: Math.max(40, headerText.implicitHeight + Theme.pad * 2)
            radius: Theme.radius
            color: Theme.hoverMuted

            Text {
                id: headerText
                anchors.centerIn: parent
                text: "Setting"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
            }
        }

        // Stub copy: "still working rn..."
        Text {
            id: stubCopy
            anchors.centerIn: parent
            text: "still working rn..."
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSize * 1.2)
            font.weight: Font.Normal
        }
    }
}
