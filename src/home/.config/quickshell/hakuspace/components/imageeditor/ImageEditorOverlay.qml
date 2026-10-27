import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../settings" as Settings
import "../wallpaper" as Wallpaper

PanelWindow {
    id: root
    required property var modelData
    // A stable full-output window owns input; only its internal aperture animates.
    readonly property bool panelOpen: !!modelData && UiState.activePanel === "imageEditor" && UiState.imageEditorScreenName === modelData.name
    readonly property bool opening: panelOpen && !ImageEditor.closing
    readonly property bool releaseReady: !panelOpen && expansion === 0 && !motion.running
    property real expansion: 0
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: panelOpen || expansion > 0
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: UiState.nativeDialogOwner === "imageEditor" ? WlrLayer.Bottom : WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-image-editor"
    WlrLayershell.keyboardFocus: opening && UiState.ownsInteraction("imageEditor", modelData.name)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: scene; width: root.opening && !UiState.nativeDialogOpen ? scene.width : 0; height: root.opening && !UiState.nativeDialogOpen ? scene.height : 0 }

    // Reversing the same animation preserves close/reopen continuity.
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
        if (!workspace.imageReady || !ImageEditor.ready) return
        if (ImageEditor.mode === "file") {
            saveChooser.lease = UiState.beginNativeDialog("imageEditor")
            if (saveChooser.lease) saveChooser.open()
        } else ImageEditor.save("")
    }
    onOpeningChanged: animate()
    Component.onCompleted: animate()
    NumberAnimation {
        id: motion; target: root; property: "expansion"; duration: HAnimation.slow
        easing.type: Easing.InOutCubic
        onFinished: root.finishClose()
    }
    Connections {
        target: UiState
        function onNativeDialogFinished(owner, screenName) {
            if (owner === "imageEditor" && root.opening && UiState.ownsInteraction(owner, screenName)) scene.forceActiveFocus()
        }
    }
    FileDialog {
        id: saveChooser
        property int lease: 0
        fileMode: FileDialog.SaveFile
        title: "Save edited image as a new file"
        defaultSuffix: selectedNameFilter.index === 1 ? "jpg" : selectedNameFilter.index === 2 ? "webp" : "png"
        nameFilters: ["PNG image (*.png)", "JPEG image (*.jpg *.jpeg)", "WebP image (*.webp)"]
        onAccepted: { UiState.endNativeDialog(lease); ImageEditor.save(selectedFile) }
        onRejected: UiState.endNativeDialog(lease)
        Component.onDestruction: UiState.endNativeDialog(lease)
    }
    FocusScope {
        id: scene
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { ImageEditor.close(); event.accepted = true }
            else if (event.key === Qt.Key_Delete) { ImageEditor.deleteAnnotation(); event.accepted = true }
            else if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_Z) { ImageEditor.undo(!!(event.modifiers & Qt.ShiftModifier)); event.accepted = true }
                else if (event.key === Qt.Key_S) { root.save(); event.accepted = true }
            }
        }
        Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.surface, root.expansion * 0.65) }
        Item {
            id: panel
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.88, 1600)
            height: Math.min(parent.height * 0.88, 960)
            // Contract an aperture instead of scaling the image and control text.
            clip: true
            Item {
                anchors.centerIn: parent
                width: panel.width * root.expansion
                height: panel.height * (0.08 + root.expansion * 0.92)
                clip: true
                Rectangle { anchors.fill: parent; radius: Theme.largeRadius; color: Theme.surface }
                Item {
                    // Add a shared inset around every control and the image workspace.
                    width: panel.width - 24; height: panel.height - 24; anchors.centerIn: parent
                    Row {
                        id: header
                        x: 16; y: 12; spacing: 8
                        Settings.SettingsActionButton {
                            width: 80; height: 38; text: "Cancel"; enabled: !ImageEditor.busy; activeFocusOnTab: true
                            onClicked: ImageEditor.close(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }
                        Text {
                            width: Math.max(80, panel.width - 440); height: 38; verticalAlignment: Text.AlignVCenter
                            text: ImageEditor.sourcePath.split("/").pop() || "Image editor"
                            textFormat: Text.PlainText; elide: Text.ElideMiddle; color: Theme.fg; font.pixelSize: Theme.fontSize
                        }
                        Settings.SettingsActionButton {
                            width: 64; height: 38; text: "Undo"; enabled: !ImageEditor.busy && ImageEditor.undoStack.length > 0; activeFocusOnTab: true
                            onClicked: ImageEditor.undo(false); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }
                        Settings.SettingsActionButton {
                            width: 64; height: 38; text: "Redo"; enabled: !ImageEditor.busy && ImageEditor.redoStack.length > 0; activeFocusOnTab: true
                            onClicked: ImageEditor.undo(true); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }
                        Settings.SettingsActionButton {
                            width: 100; height: 38
                            text: ImageEditor.busy ? "Working…" : ImageEditor.mode === "file" ? "Save As…" : "Save"
                            enabled: ImageEditor.ready && workspace.imageReady; selected: true; activeFocusOnTab: true
                            onClicked: root.save(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }
                    }
                    ImageEditorToolbar {
                        x: 16 + (1 - root.expansion) * -120; y: 66
                        height: parent.height - 130
                        opacity: Math.max(0, (root.expansion - 0.5) * 2)
                    }
                    Row {
                        id: transforms
                        x: workspace.x; y: 66; width: workspace.width; spacing: 8
                        enabled: ImageEditor.ready
                        // Keep orientation actions separate from the drawing-tool rail.
                        Repeater {
                            model: [{label: "Rotate left 90°", icon: "󰑥", operation: "ccw"}, {label: "Rotate right 90°", icon: "󰑧", operation: "cw"},
                                {label: "Flip horizontal", icon: "󱃧", operation: "horizontal"}, {label: "Flip vertical", icon: "󱃨", operation: "vertical"}]
                            Wallpaper.WallpaperActionButton {
                                id: transformButton
                                required property var modelData
                                width: transformLabel.advanceWidth + 24; height: 40
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
                    ImageEditorWorkspace {
                        id: workspace
                        x: 132; y: 118; width: Math.max(1, parent.width - 336); height: Math.max(1, parent.height - 182)
                    }
                    Flickable {
                        x: parent.width - width - 12 + (1 - root.expansion) * 190; y: 66
                        width: 180; height: parent.height - 130; clip: true
                        contentHeight: inspector.height; boundsBehavior: Flickable.StopAtBounds
                        opacity: Math.max(0, (root.expansion - 0.5) * 2)
                        ImageEditorInspector { id: inspector }
                    }
                    Text {
                        x: 16; y: parent.height - 52; width: parent.width - 32
                        text: ImageEditor.lastError || (ImageEditor.sourceWidth + "×" + ImageEditor.sourceHeight + " → "
                            + ImageEditor.outputSize.width + "×" + ImageEditor.outputSize.height + "    Fit " + Math.round(workspace.displayScale * 100) + "%")
                        textFormat: Text.PlainText; color: ImageEditor.lastError ? Theme.danger : Theme.fgDim
                        font.pixelSize: Theme.fontSize; wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
