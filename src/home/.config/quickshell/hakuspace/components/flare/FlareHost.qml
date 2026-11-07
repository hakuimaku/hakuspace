import QtQuick
import "../../services"

Item {
    id: root
    property Item anchorItem: null
    property var anchorRect: null
    property var hostRect: ({x: 0, y: 0, width: root.width, height: root.height})
    readonly property var localizedAnchorRect: anchorRect ? ScreenGeometry.localizeRect(anchorRect, hostRect)
        : anchorItem ? ScreenGeometry.localizeRect(ScreenGeometry.itemRect(anchorItem), hostRect) : null
    // Transpose only the silhouette geometry; hosted controls stay upright.
    readonly property bool leftAttached: attach === FlareHost.Left
    readonly property real naturalDepth: leftAttached ? naturalContentWidth + horizontalPadding * 2 : naturalContentHeight + verticalPadding * 2
    property bool shown: false
    property Component content: null
    property var contentProps: ({})
    property var contentKey: null
    property real maxWidth: 360
    property real horizontalPadding: 12
    property real verticalPadding: 8
    property color surfaceColor: Theme.surface
    property int contentFadeDuration: HAnimation.effects
    property bool contentReady: false
    property var interactionEnvelope: ({ start: 0, end: 0, height: 0 })

    function extendInteractionEnvelope() {
        if (!shown || end <= start) return
        var previous = interactionEnvelope
        interactionEnvelope = {
            start: previous.end > previous.start ? Math.min(previous.start, start) : start,
            end: Math.max(previous.end, end),
            height: Math.max(previous.height, currentHeight, naturalDepth)
        }
    }
    onStartChanged: extendInteractionEnvelope()
    onEndChanged: extendInteractionEnvelope()
    onCurrentHeightChanged: extendInteractionEnvelope()
    onNaturalContentHeightChanged: extendInteractionEnvelope()
    onNaturalContentWidthChanged: extendInteractionEnvelope()

    onShownChanged: {
        if (!shown) contentReady = false
        else {
            interactionEnvelope = { start: 0, end: 0, height: 0 }
            if (contentItem.ready) contentReady = true
        }
    }

    Connections {
        target: contentItem
        function onReadyChanged() {
            if (root.shown && contentItem.ready) root.contentReady = true
        }
    }
    
    enum AttachMode { Top, Left, Right, Bottom }
    property int attach: FlareHost.Top
    
    property alias start: morph.mStart
    property alias end: morph.mEnd
    property alias currentHeight: morph.mHeight
    property alias naturalContentHeight: contentItem.naturalHeight
    property alias naturalContentWidth: contentItem.naturalWidth
    property alias hugging: morph.hugging
    signal settled(bool isShown)
    
    property var wBounds: leftAttached ? ({start: ScreenGeometry.topBorderThickness, end: height - ScreenGeometry.bottomInset}) : ScreenGeometry.horizontalBounds(root.width)
    
    FlareMorph {
        id: morph
        anchorItem: root.leftAttached ? null : root.anchorItem
        anchorRect: root.leftAttached && root.localizedAnchorRect ? ({x: root.localizedAnchorRect.y,
            y: root.localizedAnchorRect.x, width: root.localizedAnchorRect.height, height: root.localizedAnchorRect.width}) : root.anchorRect
        hostRect: root.leftAttached ? ({x: 0, y: 0, width: root.height, height: root.width}) : root.hostRect
        shown: root.shown && root.contentReady
        contentW: root.leftAttached ? contentItem.naturalHeight : contentItem.naturalWidth
        contentH: root.leftAttached ? contentItem.naturalWidth : contentItem.naturalHeight
        padX: (root.leftAttached ? root.verticalPadding : root.horizontalPadding) * 2
        padY: (root.leftAttached ? root.horizontalPadding : root.verticalPadding) * 2
        bounds: root.wBounds
        maxW: root.leftAttached ? root.wBounds.end - root.wBounds.start : root.maxWidth
        snap: 2 * Theme.hugRadius
        onSettled: function(s) {
            if (s) root.interactionEnvelope = {
                start: morph.mStart, end: morph.mEnd,
                height: Math.max(morph.mHeight, root.naturalDepth)
            }
            root.settled(s)
            contentItem.settle(s)
        }
    }
    
    FlareSurface {
        id: surface
        attach: root.attach
        transform: Matrix4x4 {
            matrix: root.leftAttached ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                : Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }
        start: morph.mStart
        end: morph.mEnd
        currentHeight: morph.mHeight
        bounds: root.wBounds
        r: Theme.largeRadius + 8
        rf: Theme.hugRadius
        surfaceColor: root.surfaceColor
        
    }
    // Clip the reveal on its physical axis without rotating text or input coordinates.
    Item {
        x: root.leftAttached ? 0 : morph.mStart
        y: root.leftAttached ? morph.mStart : root.attach === FlareHost.Bottom ? -morph.mHeight : 0
        width: root.leftAttached ? morph.mHeight : Math.max(0, morph.mEnd - morph.mStart)
        height: root.leftAttached ? Math.max(0, morph.mEnd - morph.mStart) : morph.mHeight
        clip: true
        FlareContent {
            id: contentItem
            shown: root.shown
            fadeDuration: root.contentFadeDuration
            // The reveal clips a stationary left-anchored page instead of moving its center.
            anchors.centerIn: root.leftAttached ? undefined : parent
            anchors.verticalCenter: root.leftAttached ? parent.verticalCenter : undefined
            x: root.leftAttached ? root.horizontalPadding : 0
            width: root.leftAttached ? naturalWidth : 0
            height: root.leftAttached ? naturalHeight : 0
            contentComponent: root.content
            contentProps: root.contentProps
            contentKey: root.contentKey
            maxWidth: root.maxWidth
        }
    }
}
