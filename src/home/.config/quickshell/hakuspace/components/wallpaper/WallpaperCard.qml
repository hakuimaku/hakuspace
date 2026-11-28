import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../../services"

Item {
    id: root
    // The carousel owns positioning, scaling and selection.
    required property var wallpaper
    property bool chosen: false
    property bool compactCard: false
    // A theme outline keeps white Leftbar artwork distinct from its cradle.
    property bool outlineSelection: false
    // Presentations choose clipping and a fixed decode budget before navigation.
    property real cornerRadius: Theme.largeRadius
    property real decodeScale: 1
    // Only the opening selection needs a temporary circular mask.
    property real revealProgress: 1
    // A brief scale pulse adds a subtle highlight to the closing selection.
    property real pulse: 1
    // Resolve the active layer reactively via integer layerRevision without rebuilding PathView's model.
    readonly property var currentLayer: WallpaperLibrary.resolveStack(wallpaper, WallpaperLibrary.layerRevision) || wallpaper
    readonly property int layerCount: currentLayer && currentLayer.layerCount ? currentLayer.layerCount : 1
    readonly property bool isStacked: layerCount > 1
    readonly property string nextBackingThumb: currentLayer && currentLayer.backingThumbnails && currentLayer.backingThumbnails.length
        ? currentLayer.backingThumbnails[0] : ""
    readonly property bool activeWallpaper: WallpaperService.current.path === currentLayer.path
    // Missing previews settle as errors instead of blocking the opening motion.
    readonly property bool thumbnailSettled: preview.status === Image.Ready || preview.status === Image.Error || !preview.source.toString()

    // Vertical roll transition state when flipping layers inside a stacked card.
    property string lastGroupKey: ""
    property string outgoingThumb: ""
    property real rollProgress: 1
    property int rollDirection: 1
    readonly property bool rolling: rollAnim.running && outgoingThumb.length > 0

    signal selected()
    signal applied()
    height: width * 9 / 16
    Accessible.role: Accessible.ListItem
    Accessible.name: currentLayer.label + (currentLayer.category ? ", " + currentLayer.category : "") + ", " + currentLayer.kind
    Accessible.selected: chosen
    Accessible.onPressAction: selected()

    onWallpaperChanged: {
        var nextKey = wallpaper && wallpaper.groupKey ? wallpaper.groupKey : ""
        if (nextKey !== lastGroupKey) {
            rollAnim.stop()
            outgoingThumb = ""
            rollProgress = 1
            lastGroupKey = nextKey
        }
    }

    Connections {
        target: WallpaperLibrary
        function onLayerCycled(groupKey, step) {
            if (!root.wallpaper || root.wallpaper.groupKey !== groupKey) return
            root.outgoingThumb = root.currentLayer.thumbnail || ""
            root.rollDirection = step >= 0 ? 1 : -1
            root.rollProgress = 0
            rollAnim.restart()
        }
    }

    NumberAnimation {
        id: rollAnim
        target: root
        property: "rollProgress"
        from: 0
        to: 1
        duration: HAnimation.slow
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.moduleCurve
        onFinished: root.outgoingThumb = ""
    }

    // Lightweight third-card deck edge avoids extra image decodes when 3+ layers exist.
    Rectangle {
        objectName: "wallpaper-stack-back-2"
        z: -2
        anchors.fill: parent
        visible: root.isStacked && root.layerCount >= 3 && root.revealProgress >= 1
        radius: root.cornerRadius
        color: Theme.hoverMuted
        border.width: 0
        opacity: 0.72
        transform: [
            Scale {
                origin.x: root.width / 2
                origin.y: root.height / 2
                xScale: 0.88
                yScale: 0.88
            },
            Translate { y: root.compactCard ? -11 : -18 }
        ]
    }

    // Show the immediate next layer peeking behind the front card.
    ClippingRectangle {
        id: backingLayer
        objectName: "wallpaper-stack-back-1"
        z: -1
        anchors.fill: parent
        visible: root.isStacked && root.revealProgress >= 1
        radius: root.cornerRadius
        color: Theme.surface
        opacity: 0.92
        transform: [
            Scale {
                origin.x: root.width / 2
                origin.y: root.height / 2
                xScale: 0.94
                yScale: 0.94
            },
            Translate { y: root.compactCard ? -6 : -10 }
        ]
        Image {
            anchors.fill: parent
            source: backingLayer.visible ? WallpaperService.fileUrl(root.nextBackingThumb) : ""
            sourceSize: Qt.size(Math.max(1, Math.ceil(root.width * 0.5 * root.decodeScale)),
                Math.max(1, Math.ceil(root.height * 0.5 * root.decodeScale)))
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            cache: false
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Theme.surface, 0.28)
        }
    }

    // Reuse the shell's clipping primitive for still-image previews and vertical layer rolls.
    ClippingRectangle {
        id: artwork
        anchors.fill: parent
        radius: root.cornerRadius
        color: Theme.hoverMuted
        Text {
            anchors.centerIn: parent
            visible: preview.status !== Image.Ready && !root.rolling
            text: root.currentLayer.kind === "video" ? "▶" : "◇"
            color: Theme.fgMuted; font.pixelSize: 32
        }
        Image {
            id: outgoingPreview
            anchors.fill: parent
            visible: root.rolling
            source: root.rolling ? WallpaperService.fileUrl(root.outgoingThumb) : ""
            sourceSize: preview.sourceSize
            asynchronous: false
            fillMode: Image.PreserveAspectCrop
            cache: false
            opacity: 1 - 0.22 * root.rollProgress
            transform: [
                Scale {
                    origin.x: outgoingPreview.width / 2
                    origin.y: outgoingPreview.height / 2
                    xScale: 1 - 0.04 * root.rollProgress
                    yScale: 1 - 0.04 * root.rollProgress
                },
                Translate {
                    y: -root.rollProgress * root.height * root.rollDirection
                }
            ]
        }
        Image {
            id: preview
            objectName: "wallpaperThumbnail"
            anchors.fill: parent
            source: WallpaperService.fileUrl(root.currentLayer.thumbnail)
            sourceSize: Qt.size(Math.ceil(root.width * root.decodeScale * (root.Window.window ? root.Window.window.devicePixelRatio : 1)),
                Math.ceil(root.height * root.decodeScale * (root.Window.window ? root.Window.window.devicePixelRatio : 1)))
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            cache: false
            opacity: root.rolling ? 0.78 + 0.22 * root.rollProgress : 1
            transform: [
                Scale {
                    origin.x: preview.width / 2
                    origin.y: preview.height / 2
                    xScale: root.rolling ? 0.96 + 0.04 * root.rollProgress : 1
                    yScale: root.rolling ? 0.96 + 0.04 * root.rollProgress : 1
                },
                Translate {
                    y: root.rolling ? (1 - root.rollProgress) * root.height * root.rollDirection : 0
                }
            ]
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
        z: 2
        onClicked: root.selected()
        onDoubleClicked: if (root.chosen) root.applied()
    }
}
