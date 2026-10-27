import QtQuick
import QtQuick.Window
import "../../services"

Item {
    id: root
    // Fit the entire oriented image; crop shading leaves annotation coordinates unchanged.
    // Leave room outside the image for crop handles and separation from toolbars.
    readonly property real imagePadding: 28
    readonly property real fit: Math.min(Math.max(1, width - imagePadding * 2) / Math.max(1, ImageEditor.orientedWidth),
        Math.max(1, height - imagePadding * 2) / Math.max(1, ImageEditor.orientedHeight))
    readonly property real displayScale: fit
    readonly property bool imageReady: image.status === Image.Ready
    clip: true
    Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.surface, 0.6) }
    Item {
        id: plane
        width: ImageEditor.orientedWidth * root.displayScale
        height: ImageEditor.orientedHeight * root.displayScale
        anchors.centerIn: parent
        // Mirror after rotation, matching the backend and normalized geometry engine.
        transform: Scale { origin.x: plane.width / 2; origin.y: plane.height / 2; xScale: ImageEditor.flipX ? -1 : 1; yScale: ImageEditor.flipY ? -1 : 1 }
        Image {
            id: image
            anchors.centerIn: parent
            width: ImageEditor.sourceWidth * root.displayScale
            height: ImageEditor.sourceHeight * root.displayScale
            rotation: ImageEditor.rotation
            source: ImageEditor.sourcePath && ImageEditor.sourceWidth ? "file://" + encodeURI(ImageEditor.sourcePath).replace(/#/g, "%23").replace(/\?/g, "%3F") : ""
            sourceSize: Qt.size(Math.max(1, Math.ceil(width * (root.Window.window ? root.Window.window.devicePixelRatio : 1))),
                Math.max(1, Math.ceil(height * (root.Window.window ? root.Window.window.devicePixelRatio : 1))))
            autoTransform: true
            asynchronous: true
            cache: false
            onStatusChanged: if (status === Image.Error && ImageEditor.sourcePath && !ImageEditor.closing) ImageEditor.lastError = "The image preview could not be decoded."
        }
    }
    Item {
        anchors.centerIn: parent
        width: plane.width; height: plane.height
        visible: root.imageReady
        ImageEditorAnnotationCanvas { anchors.fill: parent }
        ImageEditorCropOverlay { anchors.fill: parent; visible: ImageEditor.tool === "crop" }
    }
}
