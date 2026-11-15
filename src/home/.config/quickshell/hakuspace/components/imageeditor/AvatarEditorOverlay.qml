import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../settings" as Settings
import "../wallpaper" as Wallpaper

PanelWindow {
    id: root
    required property var modelData
    readonly property bool panelOpen: !!modelData && UiState.activePanel === "imageEditor"
        && UiState.imageEditorScreenName === modelData.name && ImageEditor.mode === "avatar"
    readonly property bool opening: panelOpen && !ImageEditor.closing
    readonly property bool releaseReady: !panelOpen && expansion === 0 && !motion.running
    property real expansion: 0
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: panelOpen || expansion > 0
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-avatar-editor"
    WlrLayershell.keyboardFocus: opening && UiState.ownsInteraction("imageEditor", modelData.name)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: scene; width: root.opening ? scene.width : 0; height: root.opening ? scene.height : 0 }

    function animate() {
        motion.stop(); motion.to = opening ? 1 : 0
        if (expansion !== motion.to) motion.start()
        else if (!opening) Qt.callLater(finishClose)
        if (opening) scene.forceActiveFocus()
    }
    function finishClose() {
        if (expansion === 0 && !opening && modelData && ImageEditor.screenName === modelData.name) ImageEditor.finishClose()
    }
    function save() {
        if (!workspace.imageReady || !ImageEditor.ready || Avatar.busy) return
        ImageEditor.save("")
    }
    onOpeningChanged: animate()
    Component.onCompleted: animate()
    NumberAnimation {
        id: motion; target: root; property: "expansion"; duration: HAnimation.slow
        easing.type: Easing.InOutCubic
        onFinished: root.finishClose()
    }

    FocusScope {
        id: scene
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { ImageEditor.close(); event.accepted = true }
            else if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_Z) { ImageEditor.undo(!!(event.modifiers & Qt.ShiftModifier)); event.accepted = true }
                else if (event.key === Qt.Key_S) { root.save(); event.accepted = true }
            }
        }
        Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.surface, root.expansion * 0.65) }
        Item {
            id: panel
            anchors.centerIn: parent
            readonly property real horizontalOverhead: Theme.panelPadding * 2 + workspace.imagePadding * 2
            readonly property real verticalOverhead: Theme.panelPadding * 2 + 38 + Theme.spaceMd * 2
                + Theme.comfortableControlHeight + Theme.spaceSm + Math.ceil(Theme.fontSize * 1.4) + workspace.imagePadding * 2
            readonly property real minPanelWidth: Math.min(parent.width * 0.88, 560)
            readonly property real maxPanelWidth: Math.min(parent.width * 0.88, 960)
            readonly property real minPanelHeight: Math.min(parent.height * 0.84, 500)
            readonly property real maxPanelHeight: Math.min(parent.height * 0.84, 740)
            readonly property real imageAspect: ImageEditor.orientedWidth > 0 && ImageEditor.orientedHeight > 0
                ? ImageEditor.orientedWidth / ImageEditor.orientedHeight : 1
            readonly property real availImageWidth: Math.max(1, maxPanelWidth - horizontalOverhead)
            readonly property real availImageHeight: Math.max(1, maxPanelHeight - verticalOverhead)
            readonly property real fittedImageHeight: Math.min(availImageHeight, availImageWidth / imageAspect)
            readonly property real fittedImageWidth: fittedImageHeight * imageAspect
            property real targetWidth: Math.max(minPanelWidth, Math.min(maxPanelWidth, Math.round(fittedImageWidth + horizontalOverhead)))
            property real targetHeight: Math.max(minPanelHeight, Math.min(maxPanelHeight, Math.round(fittedImageHeight + verticalOverhead)))
            Behavior on targetWidth {
                enabled: root.expansion === 1 && ImageEditor.ready
                NumberAnimation { duration: HAnimation.buttonSelectDuration; easing.bezierCurve: HAnimation.buttonSelectCurve }
            }
            Behavior on targetHeight {
                enabled: root.expansion === 1 && ImageEditor.ready
                NumberAnimation { duration: HAnimation.buttonSelectDuration; easing.bezierCurve: HAnimation.buttonSelectCurve }
            }
            width: targetWidth
            height: targetHeight
            clip: true
            Item {
                anchors.centerIn: parent
                width: panel.width * root.expansion
                height: panel.height * (0.08 + root.expansion * 0.92)
                clip: true
                Rectangle { anchors.fill: parent; radius: Theme.largeRadius; color: Theme.surface }
                Item {
                    width: panel.width - Theme.panelPadding * 2
                    height: panel.height - Theme.panelPadding * 2
                    anchors.centerIn: parent
                    Row {
                        id: header
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 38
                        spacing: Theme.spaceSm
                        Settings.SettingsActionButton {
                            width: 76; height: 38; text: "Cancel"; enabled: !ImageEditor.busy; activeFocusOnTab: true
                            onClicked: ImageEditor.close(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }
                        Text {
                            width: Math.max(40, parent.width - (288 + Theme.spaceSm * 4)); height: 38; verticalAlignment: Text.AlignVCenter
                            text: "Edit avatar"
                            textFormat: Text.PlainText; elide: Text.ElideRight; color: Theme.fg; font.pixelSize: Theme.fontSize
                        }
                        Settings.SettingsActionButton {
                            width: 60; height: 38; text: "Undo"
                            enabled: !ImageEditor.busy && ImageEditor.undoStack.length > 0; activeFocusOnTab: true
                            onClicked: ImageEditor.undo(false); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }
                        Settings.SettingsActionButton {
                            width: 64; height: 38; text: "Reset"
                            enabled: !ImageEditor.busy && ImageEditor.dirty; activeFocusOnTab: true
                            onClicked: ImageEditor.reset(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }
                        Settings.SettingsActionButton {
                            width: 88; height: 38
                            text: ImageEditor.busy ? "Saving…" : "Save"
                            enabled: ImageEditor.ready && workspace.imageReady && !Avatar.busy
                            selected: true; activeFocusOnTab: true
                            onClicked: root.save(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }
                    }
                    ImageEditorWorkspace {
                        id: workspace
                        anchors.top: header.bottom
                        anchors.topMargin: Theme.spaceMd
                        anchors.bottom: transforms.top
                        anchors.bottomMargin: Theme.spaceMd
                        anchors.left: parent.left
                        anchors.right: parent.right
                        showAnnotations: false
                        circularGuide: true
                        backgroundRadius: Theme.radius
                    }
                    Row {
                        id: transforms
                        anchors.bottom: statusText.top
                        anchors.bottomMargin: Theme.spaceSm
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Theme.comfortableControlHeight
                        spacing: Theme.spaceSm
                        enabled: ImageEditor.ready
                        Repeater {
                            model: [
                                {label: "Rotate left", icon: "󰑥", operation: "ccw"},
                                {label: "Rotate right", icon: "󰑧", operation: "cw"},
                                {label: "Flip H", icon: "󱃧", operation: "horizontal"},
                                {label: "Flip V", icon: "󱃨", operation: "vertical"}
                            ]
                            Wallpaper.WallpaperActionButton {
                                id: transformButton
                                required property var modelData
                                width: transformLabel.advanceWidth + Theme.panelPadding; height: Theme.comfortableControlHeight
                                fontSize: Theme.fontSize
                                text: modelData.icon + "  " + modelData.label
                                Accessible.name: modelData.label
                                TextMetrics {
                                    id: transformLabel
                                    text: transformButton.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                                onClicked: ImageEditor.orient(modelData.operation)
                            }
                        }
                    }
                    Text {
                        id: statusText
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: ImageEditor.lastError || "Drag to crop 1:1 • Saved as 512×512 avatar"
                        textFormat: Text.PlainText
                        color: ImageEditor.lastError ? Theme.danger : Theme.fgDim
                        font.pixelSize: Theme.fontSize - 1
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
