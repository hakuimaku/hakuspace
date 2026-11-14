import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../../services"

Item {
    id: root
    // The carousel owns positioning, scaling and selection.
    required property var wallpaper
    property bool chosen: false
    // A theme outline keeps white Leftbar artwork distinct from its cradle.
    property bool outlineSelection: false
    // Presentations choose clipping and a fixed decode budget before navigation.
    property real cornerRadius: Theme.largeRadius
    property real decodeScale: 1
    // Only the opening selection needs a temporary circular mask.
    property real revealProgress: 1
    // A brief scale pulse adds a subtle highlight to the closing selection.
    property real pulse: 1
    readonly property bool activeWallpaper: WallpaperService.current.path === wallpaper.path
    // Missing previews settle as errors instead of blocking the opening motion.
    readonly property bool thumbnailSettled: preview.status === Image.Ready || preview.status === Image.Error || !preview.source.toString()
    signal selected()
    signal applied()
    height: width * 9 / 16
    Accessible.role: Accessible.ListItem
    Accessible.name: wallpaper.label + (wallpaper.category ? ", " + wallpaper.category : "") + ", " + wallpaper.kind
    Accessible.selected: chosen
    Accessible.onPressAction: selected()

    // Reuse the shell's clipping primitive for still-image previews.
    ClippingRectangle {
        id: artwork
        anchors.fill: parent
        radius: root.cornerRadius
        color: Theme.hoverMuted
        Text {
            anchors.centerIn: parent
            visible: preview.status !== Image.Ready
            text: root.wallpaper.kind === "video" ? "▶" : "◇"
            color: Theme.fgMuted; font.pixelSize: 32
        }
        Image {
            id: preview
            objectName: "wallpaperThumbnail"
            anchors.fill: parent
            source: WallpaperService.fileUrl(root.wallpaper.thumbnail)
            sourceSize: Qt.size(Math.ceil(root.width * root.decodeScale * (root.Window.window ? root.Window.window.devicePixelRatio : 1)),
                Math.ceil(root.height * root.decodeScale * (root.Window.window ? root.Window.window.devicePixelRatio : 1)))
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            cache: false
        }
        Rectangle {
            anchors.fill: parent
            color: "white"
            opacity: Math.max(0, (root.pulse - 1) * 1.4)
            visible: opacity > 0
        }
        Text {
            x: 12; y: 8
            visible: root.activeWallpaper
            text: "✓"; color: Theme.accent; font.pixelSize: 20
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.outlineSelection
        radius: root.cornerRadius
        color: "transparent"
        border.width: 1 / root.decodeScale
        border.color: root.chosen ? Theme.fgMuted : Qt.alpha(Theme.fgMuted, 0.45)
    }
    // A small badge marks the raised selection without another effect layer.
    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; margins: Theme.gap }
        visible: root.outlineSelection && root.chosen
        width: Math.max(1, Math.min(parent.width - Theme.gap * 2, selectionLabel.implicitWidth + Theme.gap * 2))
        height: selectionLabel.implicitHeight + Theme.gap
        radius: height / 2
        color: Qt.alpha(Theme.surface, 0.9)
        Text {
            id: selectionLabel
            anchors.centerIn: parent
            width: Math.max(1, parent.width - Theme.gap * 2)
            text: "SELECTED"
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, Theme.fontSize - 5)
            font.weight: Font.DemiBold
        }
    }
    // Capture only the opening selection and release both mask textures after reveal.
    Loader {
        objectName: "wallpaper-circular-reveal"
        anchors.fill: parent
        active: root.revealProgress < 1
        sourceComponent: Item {
            ShaderEffectSource {
                id: capture
                anchors.fill: parent
                sourceItem: artwork
                hideSource: true
                live: true
                visible: false
            }
            Item {
                id: circleMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    objectName: "wallpaper-reveal-circle"
                    anchors.centerIn: parent
                    width: Math.max(1, Math.hypot(root.width, root.height) * root.revealProgress)
                    height: width
                    radius: width / 2
                    color: "white"
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: capture
                maskEnabled: true
                maskSource: circleMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.025
                maskThresholdMax: 1
                maskSpreadAtMax: 0
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.selected()
        onDoubleClicked: if (root.chosen) root.applied()
    }
}
