import QtQuick
import QtQuick.Controls
import "../../services"
import "../settings" as Settings
import "AvatarCropGeometry.js" as Crop

Popup {
    id: root
    // Only the square viewport is captured; dialog controls never enter the saved image.
    property url source: ""
    property real zoom: 1
    property point pan: Qt.point(0, 0)
    readonly property bool imageReady: image.status === Image.Ready
    readonly property alias cropCanvas: canvas
    signal finished()
    width: Math.min(440, parent.width - 32)
    height: Math.min(610, parent.height - 32)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    padding: Theme.panelPadding
    modal: true
    focus: true
    closePolicy: Avatar.busy ? Popup.NoAutoClose : Popup.CloseOnEscape
    onOpened: { zoom = 1; pan = Qt.point(0, 0); reset.forceActiveFocus() }
    onClosed: { source = ""; finished() }
    background: Rectangle { radius: Theme.largeRadius; color: Theme.surface; border.width: 1; border.color: Theme.hoverMuted }
    Overlay.modal: Rectangle { color: Qt.alpha(Theme.surface, 0.7) }

    // Re-clamp pan after zoom, a new source, or a resized crop viewport.
    function clampPan() { pan = Qt.point(Crop.center(pan.x, image.width, canvas.width), Crop.center(pan.y, image.height, canvas.height)) }
    onZoomChanged: clampPan()
    Connections {
        target: Avatar
        function onCropCommitted() { root.close() }
    }
    contentItem: Column {
        spacing: Theme.spaceMd
        Text { text: "Crop avatar"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 4; font.weight: Font.DemiBold }
        Item {
            id: canvas
            width: Math.max(1, Math.min(parent.width, root.availableHeight - 210))
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true
            onWidthChanged: root.clampPan()
            Rectangle { anchors.fill: parent; color: Theme.hoverMuted }
            Image {
                id: image
                source: root.source
                sourceSize: Qt.size(2048, 2048)
                cache: false
                asynchronous: true
                readonly property real fit: Crop.cover(implicitWidth, implicitHeight, canvas.width)
                width: implicitWidth * fit * root.zoom
                height: implicitHeight * fit * root.zoom
                x: (canvas.width - width) / 2 + root.pan.x
                y: (canvas.height - height) / 2 + root.pan.y
                onStatusChanged: if (status === Image.Ready) root.clampPan()
            }
            DragHandler {
                target: null
                property point startPan: Qt.point(0, 0)
                enabled: root.imageReady && !Avatar.busy
                onActiveChanged: if (active) startPan = root.pan
                onActiveTranslationChanged: if (active) root.pan = Qt.point(
                    Crop.center(startPan.x + activeTranslation.x, image.width, canvas.width),
                    Crop.center(startPan.y + activeTranslation.y, image.height, canvas.height))
            }
            WheelHandler { enabled: !Avatar.busy; onWheel: event => { root.zoom = Math.max(1, Math.min(4, root.zoom + event.angleDelta.y / 1200)); event.accepted = true } }
        }
        Text { width: parent.width; text: image.status === Image.Error ? "This image could not be opened. Choose a supported image." : "Drag to move the image. Zoom to fit your avatar."; color: Theme.fgDescription; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
        Settings.SettingsSlider { width: parent.width; from: 1; to: 4; stepSize: 0.05; value: root.zoom; enabled: root.imageReady && !Avatar.busy; Accessible.name: "Avatar zoom"; onMoved: root.zoom = value }
        Text { width: parent.width; visible: Avatar.lastError.length > 0; text: Avatar.lastError; color: Theme.fg; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
        Row {
            spacing: Theme.spaceSm
            Settings.SettingsActionButton { id: reset; width: (root.availableWidth - 16) / 3; height: 40; text: "Reset"; enabled: !Avatar.busy; activeFocusOnTab: true; focused: activeFocus; onClicked: { root.zoom = 1; root.pan = Qt.point(0, 0) } Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
            Settings.SettingsActionButton { width: (root.availableWidth - 16) / 3; height: 40; text: "Cancel"; enabled: !Avatar.busy; activeFocusOnTab: true; focused: activeFocus; onClicked: root.close(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
            Settings.SettingsActionButton { width: (root.availableWidth - 16) / 3; height: 40; text: Avatar.busy ? "Saving…" : "Apply"; enabled: root.imageReady && !Avatar.busy; selected: true; activeFocusOnTab: true; focused: activeFocus; onClicked: Avatar.saveCrop(canvas); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
        }
    }
}
