import QtQuick
import "../../services"

Item {
    id: root
    property Item anchorItem: null
    property var anchorRect: null
    property var hostRect: ({x: 0, y: 0, width: root.width, height: root.height})
    readonly property var localizedAnchorRect: morph.localizedAnchorRect
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
            height: Math.max(previous.height, currentHeight, naturalContentHeight + root.verticalPadding * 2)
        }
    }
    onStartChanged: extendInteractionEnvelope()
    onEndChanged: extendInteractionEnvelope()
    onCurrentHeightChanged: extendInteractionEnvelope()
    onNaturalContentHeightChanged: extendInteractionEnvelope()

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
    
    property var wBounds: ScreenGeometry.horizontalBounds(root.width)
    
    FlareMorph {
        id: morph
        anchorItem: root.anchorItem
        anchorRect: root.anchorRect
        hostRect: root.hostRect
        shown: root.shown && root.contentReady
        contentW: contentItem.naturalWidth
        contentH: contentItem.naturalHeight
        padX: root.horizontalPadding * 2
        padY: root.verticalPadding * 2
        bounds: root.wBounds
        maxW: root.maxWidth
        snap: 2 * Theme.hugRadius
        onSettled: function(s) {
            if (s) root.interactionEnvelope = {
                start: morph.mStart, end: morph.mEnd,
                height: Math.max(morph.mHeight, contentItem.naturalHeight + root.verticalPadding * 2)
            }
            root.settled(s)
            contentItem.settle(s)
        }
    }
    
    FlareSurface {
        id: surface
        attach: root.attach
        start: morph.mStart
        end: morph.mEnd
        currentHeight: morph.mHeight
        bounds: root.wBounds
        r: Theme.largeRadius + 8
        rf: Theme.hugRadius
        surfaceColor: root.surfaceColor
        
        FlareContent {
            id: contentItem
            shown: root.shown
            fadeDuration: root.contentFadeDuration
            anchors.centerIn: parent
            contentComponent: root.content
            contentProps: root.contentProps
            contentKey: root.contentKey
            maxWidth: root.maxWidth
        }
    }
}
