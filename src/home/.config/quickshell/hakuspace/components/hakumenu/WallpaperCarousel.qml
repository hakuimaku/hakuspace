import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "../../services"

Item {
    id: root

    property var staticItems: []
    property var livelyItems: []
    property string loadError: ""
    property bool modelLoaded: false

    // W8 keeps Static and Lively as distinct carousel modes. Both backend
    // models remain cached, and each mode remembers its own navigation index.
    property string activeKind: "static"
    property int staticSelectedIndex: -1
    property int livelySelectedIndex: -1
    property bool staticWarm: false
    property bool livelyWarm: false

    readonly property var items: activeKind === "lively" ? livelyItems : staticItems
    readonly property int selectedIndex: activeKind === "lively" ? livelySelectedIndex : staticSelectedIndex
    readonly property var centerItem: recordForKindAt(activeKind, selectedIndex)
    readonly property real slotAspect: 16 / 9
    readonly property real maxSlotWidth: Math.max(0, width - Theme.pad * 4)
    readonly property real maxSlotHeight: Math.max(0, height - Theme.pad * 5)
    readonly property real slotWidth: Math.min(maxSlotWidth, maxSlotHeight * slotAspect)
    readonly property real slotHeight: slotWidth / slotAspect
    readonly property Item modeSwitchHitRegion: kindSwitch

    // W7 keeps wallpaper delegates stable by record index instead of reusing
    // seven physical slots whose Image.source changed on every navigation.
    // The visible deck remains center + three cards per side. Two additional
    // records per side are prefetched so a single navigation step already has
    // its incoming thumbnail warm, while decode work stays bounded.
    readonly property int sideDepth: 3
    readonly property int prefetchDepth: sideDepth + 2
    readonly property int maxActivePreviews: 1 + prefetchDepth * 2
    readonly property real decodeOverscan: 1.12
    readonly property real sideScaleBase: 0.78
    readonly property real sideScaleStep: 0.09
    readonly property real sideOffsetBase: slotWidth * 0.43
    readonly property real sideOffsetStep: slotWidth * 0.16

    // W9 motion state. Opening animation is deliberately split from the W10
    // hero reveal: side/rear cards reel into place while the whole surface
    // fades in, then the center card becomes available for the later reveal.
    property string openPhase: "idle"   // idle | waiting | opening | ready | closing
    property real openOpacity: 1.0
    property real reelProgress: 1.0
    // W10 reveals the hero through a center-out circular mask. Per the W9.2
    // runtime decision, this starts together with the rear reel rather than
    // waiting for the reel to settle.
    property real heroRevealProgress: 1.0
    property int navigationDirection: 0
    property bool navigationMotionActive: false
    property real closeGatherProgress: 0.0
    property real closeZoomProgress: 0.0
    property real closeOpacity: 1.0
    property double lastNavigationMs: 0
    signal closeAnimationFinished()
    signal applyAccepted()
    readonly property bool closing: openPhase === "closing"
    readonly property bool interactionReady: visible && openPhase === "ready"
    // Keep navigation responsive without allowing key/touchpad spam to keep
    // dozens of geometry animations alive at once. A shorter transition plus
    // a slightly wider coalescing window materially lowers scene-graph load.
    readonly property int navigationDuration: 190
    readonly property int navigationMinInterval: 85
    readonly property int closeGatherDuration: 250
    readonly property int closeZoomDuration: 340
    readonly property int openingDuration: 640
    readonly property int heroRevealDuration: 560
    readonly property real openingTravel: slotWidth * 1.35
    readonly property real reelScale: 0.62
    readonly property real reelSpacing: slotWidth * 0.34
    readonly property real reelSettleStart: 0.68
    readonly property real trailOffset: Math.max(12, Theme.gap * 1.9)

    function exactBackendSelectedIndex(records) {
        for (var i = 0; i < records.length; ++i) {
            if (records[i] && records[i].selected)
                return i
        }
        return -1
    }

    function seededIndex(records) {
        var backendIndex = exactBackendSelectedIndex(records)
        return backendIndex >= 0 ? backendIndex : (records.length > 0 ? 0 : -1)
    }

    function resetSelectionsFromBackend() {
        staticSelectedIndex = seededIndex(staticItems)
        livelySelectedIndex = seededIndex(livelyItems)

        var staticCurrent = exactBackendSelectedIndex(staticItems)
        var livelyCurrent = exactBackendSelectedIndex(livelyItems)
        if (livelyCurrent >= 0)
            activeKind = "lively"
        else if (staticCurrent >= 0 || staticItems.length > 0)
            activeKind = "static"
        else if (livelyItems.length > 0)
            activeKind = "lively"

        warmKind(activeKind)
    }

    function warmKind(kind) {
        if (kind === "lively") livelyWarm = true
        else staticWarm = true
    }

    function switchKind(kind) {
        if (!interactionReady) return
        if (kind !== "static" && kind !== "lively") return
        if (kind === activeKind) {
            warmKind(kind)
            return
        }

        activeKind = kind
        if (kind === "static" && staticSelectedIndex < 0 && staticItems.length > 0)
            staticSelectedIndex = 0
        if (kind === "lively" && livelySelectedIndex < 0 && livelyItems.length > 0)
            livelySelectedIndex = 0
        warmKind(kind)
    }

    function setActiveSelectedIndex(index) {
        if (activeKind === "lively") livelySelectedIndex = index
        else staticSelectedIndex = index
    }

    function moveSelection(delta) {
        if (!interactionReady || items.length === 0 || delta === 0) return
        var now = Date.now()
        if (now - lastNavigationMs < navigationMinInterval) return
        lastNavigationMs = now
        var base = selectedIndex >= 0 ? selectedIndex : 0
        var next = Math.max(0, Math.min(items.length - 1, base + delta))
        if (next === base) return

        navigationDirection = delta > 0 ? 1 : -1
        navigationMotionActive = true
        navigationTrailTimer.restart()
        setActiveSelectedIndex(next)
    }

    function selectPrevious() {
        moveSelection(-1)
    }

    function selectNext() {
        moveSelection(1)
    }

    function applySelected() {
        if (!interactionReady || applyProcess.running || centerItem === null) return false

        var command = centerItem.kind === "lively" ? "apply-lively" : "apply-static"
        var target = centerItem.path || centerItem.id || ""
        if (target.length === 0) return false

        applyProcess.errorOutput = ""
        applyProcess.command = [Env.binDir + "/wallpaper_ctl.sh", command, target]
        applyProcess.running = true
        return true
    }

    // Keyboard and pointer activation share one acceptance path so Enter and
    // clicking the physical center card have identical apply/close semantics.
    function acceptSelected() {
        if (!applySelected()) return false
        applyAccepted()
        return true
    }

    function recordForKindAt(kind, index) {
        var records = kind === "lively" ? livelyItems : staticItems
        return index >= 0 && index < records.length ? records[index] : null
    }

    function fileUrl(path) {
        if (!path || path.length === 0 || path[0] !== "/") return ""
        return "file://" + path
    }

    function refresh(force) {
        if (!force && modelLoaded) return
        loadError = ""
        staticSelectedIndex = -1
        livelySelectedIndex = -1
        staticWarm = false
        livelyWarm = false
        modelLoaded = false
        staticProcess.running = false
        livelyProcess.running = false
        staticProcess.command = [Env.binDir + "/wallpaper_ctl.sh", "list-static", "--json"]
        staticProcess.running = true
    }

    function beginOpenAnimation() {
        if (!visible) return
        closeSequence.stop()
        closeGatherProgress = 0.0
        closeZoomProgress = 0.0
        closeOpacity = 1.0
        if (!modelLoaded) {
            openSequence.stop()
            openPhase = "waiting"
            openOpacity = 0.0
            reelProgress = 0.0
            heroRevealProgress = 0.0
            return
        }

        navigationTrailTimer.stop()
        navigationMotionActive = false
        navigationDirection = 0
        openSequence.stop()
        openPhase = "opening"
        openOpacity = 0.0
        reelProgress = 0.0
        heroRevealProgress = 0.0
        openSequence.start()
    }

    function beginCloseAnimation() {
        if (!visible || closing) return
        openSequence.stop()
        navigationTrailTimer.stop()
        navigationMotionActive = false
        navigationDirection = 0
        closeSequence.stop()

        // Close always starts from a fully formed deck. This avoids leaving
        // persistent mask/reel state behind if close is requested immediately
        // after opening or during a rapid toggle.
        openOpacity = Math.max(openOpacity, 0.001)
        reelProgress = 1.0
        heroRevealProgress = 1.0
        closeGatherProgress = 0.0
        closeZoomProgress = 0.0
        closeOpacity = 1.0
        openPhase = "closing"
        closeSequence.start()
    }

    function cancelCloseAnimation() {
        if (!closing) return
        closeSequence.stop()
        closeGatherProgress = 0.0
        closeZoomProgress = 0.0
        closeOpacity = 1.0
        openOpacity = 1.0
        reelProgress = 1.0
        heroRevealProgress = 1.0
        openPhase = "ready"
    }

    function resetOpenAnimation() {
        openSequence.stop()
        closeSequence.stop()
        navigationTrailTimer.stop()
        navigationMotionActive = false
        navigationDirection = 0
        openPhase = "idle"
        openOpacity = 1.0
        reelProgress = 1.0
        heroRevealProgress = 1.0
        closeGatherProgress = 0.0
        closeZoomProgress = 0.0
        closeOpacity = 1.0
        lastNavigationMs = 0
    }

    function parseRecords(data, kind) {
        var line = (data || "").trim()
        if (line.length === 0) return []
        try {
            var parsed = JSON.parse(line)
            return Array.isArray(parsed) ? parsed : []
        } catch (e) {
            loadError = "Unable to read " + kind + " wallpapers"
            return []
        }
    }

    opacity: openOpacity * closeOpacity
    // W11.1 close phase 2 is a centered zoom-out + fade. Scaling the carousel
    // as one surface avoids the layered/orbit look of the previous vortex.
    scale: closing ? (1.0 - closeZoomProgress * 0.28) : 1.0
    transformOrigin: Item.Center

    onVisibleChanged: {
        // Keep the model/delegate cache alive across close/reopen cycles. The
        // panel object itself is persistent, so reopening should not query the
        // backend or rebuild every thumbnail again.
        if (visible) {
            if (!modelLoaded) {
                beginOpenAnimation()
                refresh(false)
            } else {
                beginOpenAnimation()
            }
        } else {
            resetOpenAnimation()
        }
    }

    Component.onCompleted: {
        if (visible) {
            if (!modelLoaded) {
                beginOpenAnimation()
                refresh(false)
            } else {
                beginOpenAnimation()
            }
        }
    }

    Timer {
        id: navigationTrailTimer
        interval: root.navigationDuration + 70
        repeat: false
        onTriggered: {
            root.navigationMotionActive = false
            root.navigationDirection = 0
        }
    }

    ParallelAnimation {
        id: openSequence

        NumberAnimation {
            target: root
            property: "openOpacity"
            from: 0.0
            to: 1.0
            duration: 300
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "reelProgress"
            from: 0.0
            to: 1.0
            duration: root.openingDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "heroRevealProgress"
            from: 0.0
            to: 1.0
            duration: root.heroRevealDuration
            easing.type: Easing.OutQuart
        }

        onFinished: {
            root.openOpacity = 1.0
            root.reelProgress = 1.0
            root.heroRevealProgress = 1.0
            root.openPhase = "ready"
        }
    }

    SequentialAnimation {
        id: closeSequence

        // Phase 1: both side decks collapse toward the physical hero slot.
        NumberAnimation {
            target: root
            property: "closeGatherProgress"
            from: 0.0
            to: 1.0
            duration: root.closeGatherDuration
            easing.type: Easing.InOutCubic
        }

        // Phase 2: the gathered deck zooms away from the viewer while fading
        // out. No rotation/orbit is used; the entire carousel scales around its
        // physical center so the exit reads as one coherent surface.
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "closeZoomProgress"
                from: 0.0
                to: 1.0
                duration: root.closeZoomDuration
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "closeOpacity"
                from: 1.0
                to: 0.0
                duration: root.closeZoomDuration
                easing.type: Easing.InQuad
            }
        }

        onFinished: {
            root.closeGatherProgress = 1.0
            root.closeZoomProgress = 1.0
            root.closeOpacity = 0.0
            root.closeAnimationFinished()
        }
    }

    Process {
        id: staticProcess
        property string output: ""

        stdout: SplitParser {
            onRead: data => staticProcess.output += data
        }

        onRunningChanged: {
            if (running) output = ""
        }

        onExited: exitCode => {
            root.staticItems = exitCode === 0 ? root.parseRecords(output, "static") : []
            if (exitCode !== 0) root.loadError = "Unable to list static wallpapers"
            livelyProcess.command = [Env.binDir + "/wallpaper_ctl.sh", "list-lively", "--json"]
            livelyProcess.running = true
        }
    }

    Process {
        id: livelyProcess
        property string output: ""

        stdout: SplitParser {
            onRead: data => livelyProcess.output += data
        }

        onRunningChanged: {
            if (running) output = ""
        }

        onExited: exitCode => {
            root.livelyItems = exitCode === 0 ? root.parseRecords(output, "lively") : []
            if (exitCode !== 0 && root.loadError.length === 0)
                root.loadError = "Unable to list lively wallpapers"
            root.resetSelectionsFromBackend()
            root.modelLoaded = true
            if (root.visible) root.beginOpenAnimation()
        }
    }

    Process {
        id: applyProcess
        property string errorOutput: ""

        stderr: SplitParser {
            onRead: data => applyProcess.errorOutput += data
        }

        onRunningChanged: {
            if (running) errorOutput = ""
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                // The chosen index is already the UI truth. Keep the cached
                // model/delegates intact instead of refreshing and causing a
                // thumbnail rebuild after every apply.
                return
            }

            var message = errorOutput.trim()
            console.warn("Wallpaper apply failed" + (message.length > 0 ? ": " + message : ""))
        }
    }

    WheelHandler {
        id: wheelNavigation
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (!root.interactionReady) {
                event.accepted = true
                return
            }
            var delta = Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x)
                        ? event.angleDelta.y
                        : event.angleDelta.x
            if (delta === 0) return
            if (delta > 0) root.selectPrevious()
            else root.selectNext()
            event.accepted = true
        }
    }

    Component {
        id: wallpaperCardDelegate

        Item {
            id: card

            required property int index
            required property var modelData

            readonly property var record: modelData
            readonly property string deckKind: record && record.kind === "lively" ? "lively" : "static"
            readonly property int deckSelectedIndex: deckKind === "lively"
                                                        ? root.livelySelectedIndex
                                                        : root.staticSelectedIndex
            readonly property int relativeIndex: deckSelectedIndex < 0 ? 999999 : index - deckSelectedIndex
            readonly property int depth: Math.abs(relativeIndex)
            readonly property bool isCenter: relativeIndex === 0
            readonly property bool inDeck: depth <= root.sideDepth
            // Keep one transparent outer slot alive so navigation has a real
            // incoming/outgoing card to animate instead of popping at depth 3.
            readonly property bool inMotionDeck: depth <= root.sideDepth + 1
            readonly property bool inPrefetchWindow: depth <= root.prefetchDepth
            readonly property bool deckActive: deckKind === root.activeKind
            readonly property bool deckWarm: deckKind === "lively" ? root.livelyWarm : root.staticWarm
            readonly property real cardScale: isCenter
                                                  ? 1.0
                                                  : Math.max(0.45, root.sideScaleBase - (depth - 1) * root.sideScaleStep)
            readonly property real centerOffset: isCenter
                                                    ? 0
                                                    : root.sideOffsetBase + (depth - 1) * root.sideOffsetStep
            readonly property string previewPath: record ? (record.thumbnail || record.path || "") : ""
            readonly property bool heroRevealActive: isCenter
                                                       && root.openPhase === "opening"
                                                       && root.heroRevealProgress < 0.999
            readonly property real heroRevealDiameter: Math.sqrt(width * width + height * height)
                                                         * root.heroRevealProgress

            // Opening is a real horizontal reel first, then a short settle into
            // the stacked deck. During the reel all rear cards share one row
            // and sweep together across the screen instead of merely fading at
            // their final deck positions.
            readonly property real reelScrollProgress: root.openPhase === "opening"
                                                        ? Math.min(1.0, root.reelProgress / root.reelSettleStart)
                                                        : 1.0
            readonly property real reelSettleProgress: root.openPhase === "opening"
                                                        ? Math.max(0.0, Math.min(1.0,
                                                            (root.reelProgress - root.reelSettleStart)
                                                            / (1.0 - root.reelSettleStart)))
                                                        : 1.0
            readonly property real finalWidth: root.slotWidth * cardScale
            readonly property real finalHeight: root.slotHeight * cardScale
            readonly property real finalX: root.width / 2
                                             + (relativeIndex < 0 ? -centerOffset : relativeIndex > 0 ? centerOffset : 0)
                                             - finalWidth / 2
            readonly property real finalY: root.height / 2 - finalHeight / 2
                                             + (isCenter ? 0 : depth * Theme.gap * 0.35)
            // W11.1 close geometry. Phase 1 only gathers the side decks toward
            // the hero slot. Phase 2 is handled by root.closeZoomProgress so
            // the whole carousel zooms/fades as one coherent surface.
            readonly property real finalCenterX: finalX + finalWidth / 2
            readonly property real finalCenterY: finalY + finalHeight / 2
            readonly property real closeBaseDx: finalCenterX - root.width / 2
            readonly property real closeBaseDy: finalCenterY - root.height / 2
            readonly property real closeGatherFactor: 1.0 - root.closeGatherProgress * 0.74
            readonly property real closeGatherDx: closeBaseDx * closeGatherFactor
            readonly property real closeGatherDy: closeBaseDy * closeGatherFactor
            readonly property real closeScale: 1.0 - root.closeGatherProgress * 0.08
            readonly property real closeWidth: finalWidth * closeScale
            readonly property real closeHeight: finalHeight * closeScale
            readonly property real closeX: root.width / 2 + closeGatherDx - closeWidth / 2
            readonly property real closeY: root.height / 2 + closeGatherDy - closeHeight / 2

            readonly property real reelWidth: root.slotWidth * root.reelScale
            readonly property real reelHeight: root.slotHeight * root.reelScale
            readonly property real reelX: root.width / 2
                                            + relativeIndex * root.reelSpacing
                                            + (1.0 - reelScrollProgress) * root.openingTravel
                                            - reelWidth / 2
            readonly property real reelY: root.height / 2 - reelHeight / 2
            readonly property int trailSign: root.openPhase === "opening"
                                                ? 1
                                                : (root.navigationDirection >= 0 ? 1 : -1)
            // Opening can afford the full reel trail. During rapid navigation
            // only the two nearest side cards keep a trail; farther cards move
            // without duplicate texture draws, which prevents GPU fill-rate
            // spikes when arrows/wheel are spammed.
            readonly property bool trailVisible: deckActive && !isCenter
                                                  && ((root.openPhase === "opening" && inMotionDeck)
                                                      || (root.navigationMotionActive && depth <= 2))
            // W9.2: the hero card now participates in the opening fade from
            // frame one instead of waiting for the reel to settle. The later
            // circular reveal pass (W10) can replace this presentation without
            // reintroducing an artificial delay.
            readonly property real finalOpacity: isCenter
                                                    ? 1.0
                                                    : (depth > root.sideDepth
                                                       ? 0.0
                                                       : Math.max(0.42, 0.88 - (depth - 1) * 0.16))

            width: root.closing
                   ? closeWidth
                   : (root.openPhase === "opening" && !isCenter
                      ? reelWidth + (finalWidth - reelWidth) * reelSettleProgress
                      : finalWidth)
            height: root.closing
                    ? closeHeight
                    : (root.openPhase === "opening" && !isCenter
                       ? reelHeight + (finalHeight - reelHeight) * reelSettleProgress
                       : finalHeight)
            x: root.closing
               ? closeX
               : (root.openPhase === "opening" && !isCenter
                  ? reelX + (finalX - reelX) * reelSettleProgress
                  : finalX)
            y: root.closing
               ? closeY
               : (root.openPhase === "opening" && !isCenter
                  ? reelY + (finalY - reelY) * reelSettleProgress
                  : finalY)
            rotation: 0.0
            transformOrigin: Item.Center
            z: isCenter ? 100 : Math.max(0, root.sideDepth - depth)
            visible: deckActive && record !== null && (isCenter || inMotionDeck)
            opacity: root.closing
                     ? finalOpacity
                     : (root.openPhase === "opening" && !isCenter
                        ? Math.min(finalOpacity, 0.30 + reelScrollProgress * 0.58)
                        : finalOpacity)

            // W9.3: use one real soft shadow instead of a flat offset block.
            // The opaque caster is fully covered by cardSurface; MultiEffect
            // contributes only the blurred footprint that extends around it.
            Rectangle {
                id: shadowCaster
                anchors.fill: parent
                color: "#ff000000"
                radius: 0
                // MultiEffect can sample a hidden source. Keeping the caster
                // itself hidden avoids exposing a hard black rectangle while
                // W10 is revealing the center card through a circular mask.
                visible: false
            }

            MultiEffect {
                anchors.fill: shadowCaster
                source: shadowCaster
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: "#ff000000"
                shadowOpacity: card.isCenter ? 0.30 : Math.max(0.12, 0.22 - (card.depth - 1) * 0.03)
                shadowBlur: card.isCenter ? 0.48 : 0.40
                shadowHorizontalOffset: 0
                shadowVerticalOffset: card.isCenter ? 9 : 6
                shadowScale: 1.0
                blurMax: 32
                // The hero shadow appears only after the circular reveal has
                // reached the card corners; side-card shadows stay unchanged.
                // Side-card blur is visually expendable while the deck is in
                // fast navigation motion. Suppress those expensive effects
                // temporarily and restore them as soon as the motion settles.
                visible: (!card.isCenter || !card.heroRevealActive)
                         && (!root.navigationMotionActive || card.isCenter)
            }

            // Directional image trails approximate motion blur without a live
            // blur shader. They reuse the same cached source and only exist
            // while a reel/navigation transition is active.
            Image {
                x: card.trailSign * root.trailOffset * 2.0
                y: 0
                width: parent.width
                height: parent.height
                source: preview.source
                sourceSize: preview.sourceSize
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                opacity: card.trailVisible && root.openPhase === "opening" ? 0.09 : 0.0
                visible: opacity > 0 && status === Image.Ready
            }

            Image {
                x: card.trailSign * root.trailOffset
                y: 0
                width: parent.width
                height: parent.height
                source: preview.source
                sourceSize: preview.sourceSize
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                opacity: card.trailVisible ? 0.16 : 0.0
                visible: opacity > 0 && status === Image.Ready
            }

            Rectangle {
                id: cardSurface
                anchors.fill: parent
                radius: 0
                // MultiEffect renders this hidden source during W10. Once the
                // circular reveal completes the original surface resumes, so
                // the steady-state carousel pays no mask/effect cost.
                visible: !card.heroRevealActive
                color: Theme.surface
                border.width: 0
                clip: true

                Image {
                    id: preview
                    anchors.fill: parent
                    // Once a mode has been visited, its bounded prefetch set
                    // stays warm even while the other kind is active. This
                    // preserves W7's stable-source guarantee across repeated
                    // Static/Lively switches instead of rebuilding thumbnails.
                    source: card.deckWarm && card.inPrefetchWindow
                            ? root.fileUrl(card.previewPath)
                            : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    sourceSize: Qt.size(
                        Math.max(1, Math.ceil(root.slotWidth * root.decodeOverscan)),
                        Math.max(1, Math.ceil(root.slotHeight * root.decodeOverscan))
                    )
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#24000000"
                    visible: !card.isCenter
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(Theme.fontSize * 2.2, Theme.pad * 2.2)
                    color: "#b0000000"
                    visible: card.isCenter && card.record !== null

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.pad
                        anchors.right: kindLabel.left
                        anchors.rightMargin: Theme.gap
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.record ? card.record.label : ""
                        color: Theme.fg
                        elide: Text.ElideMiddle
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        id: kindLabel
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.pad
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.record ? (card.deckKind === "lively" ? "󰕧" : "󰋩") : ""
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                    }
                }
            }

            // Full-card alpha mask containing one opaque circle. The mask item
            // is hidden from normal rendering but layered so MultiEffect can
            // sample its alpha texture without a custom shader.
            Item {
                id: heroMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(1, card.heroRevealDiameter)
                    height: width
                    radius: width / 2
                    color: "white"
                }
            }

            MultiEffect {
                id: heroRevealEffect
                anchors.fill: cardSurface
                source: cardSurface
                visible: card.heroRevealActive
                maskEnabled: true
                maskSource: heroMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.025
                maskThresholdMax: 1.0
                maskSpreadAtMax: 0.0
            }

            MouseArea {
                anchors.fill: parent
                z: 500
                enabled: card.isCenter && root.interactionReady
                acceptedButtons: Qt.LeftButton
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.acceptSelected()
            }

            Behavior on x {
                enabled: root.openPhase === "ready" && card.deckActive && card.inPrefetchWindow
                NumberAnimation {
                    duration: root.navigationDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: root.openPhase === "ready" && card.deckActive && card.inPrefetchWindow
                NumberAnimation { duration: root.navigationDuration; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                enabled: root.openPhase === "ready" && card.deckActive && card.inPrefetchWindow
                NumberAnimation { duration: root.navigationDuration; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                enabled: root.openPhase === "ready" && card.deckActive && card.inPrefetchWindow
                NumberAnimation { duration: root.navigationDuration; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                enabled: root.openPhase === "ready" && card.deckActive && card.inPrefetchWindow
                NumberAnimation { duration: root.navigationDuration; easing.type: Easing.OutCubic }
            }
        }
    }

    // Keep both delegate sets alive. Switching kinds therefore changes which
    // deck is presented, not the identity of every wallpaper image.
    Repeater {
        model: root.staticItems
        delegate: wallpaperCardDelegate
    }

    Repeater {
        model: root.livelyItems
        delegate: wallpaperCardDelegate
    }

    Item {
        id: kindSwitch
        z: 300
        readonly property real trackWidth: Math.max(272, Theme.fontSize * 18)
        readonly property real trackHeight: Math.max(48, Theme.fontSize * 3.0)
        readonly property real selectedOverflow: 5
        readonly property real laneWidth: trackWidth / 2
        readonly property real hitPadding: selectedOverflow
                                           + (laneWidth + selectedOverflow * 2) * 0.11 / 2
        // Keep the current hover owner above its neighbor until the pointer leaves it.
        property string hoveredKind: ""

        width: trackWidth + hitPadding * 2
        height: trackHeight + hitPadding * 2
        x: root.width / 2 - width / 2
        y: root.height / 2 - root.slotHeight / 2 - trackHeight - Theme.pad * 1.4 - hitPadding
        opacity: root.closing ? Math.max(0.0, 1.0 - root.closeGatherProgress * 1.4) : 1.0
        scale: root.closing ? Math.max(0.72, 1.0 - root.closeGatherProgress * 0.22) : 1.0
        transformOrigin: Item.Center

        Rectangle {
            x: kindSwitch.hitPadding
            y: kindSwitch.hitPadding
            width: kindSwitch.trackWidth
            height: kindSwitch.trackHeight
            radius: height / 2
            color: "#b8000000"
        }

        Item {
            id: staticButton
            x: kindSwitch.hitPadding + (kindSwitch.laneWidth - width) / 2
            y: kindSwitch.hitPadding + (kindSwitch.trackHeight - height) / 2
            width: (kindSwitch.laneWidth + (selected ? kindSwitch.selectedOverflow * 2 : 0))
                   * (hovered ? 1.11 : 1)
            height: (kindSwitch.trackHeight + (selected ? kindSwitch.selectedOverflow * 2 : 0))
                    * (hovered ? 1.11 : 1)
            z: hovered ? 40 : (root.activeKind === "static" ? 30 : 20)
            readonly property bool hovered: kindSwitch.hoveredKind === "static"
            readonly property bool selected: root.activeKind === "static"
            readonly property int motionDuration: hovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Theme.accent
                opacity: staticButton.selected ? 1 : (staticButton.hovered ? 0.34 : 0)
            }

            Text {
                anchors.centerIn: parent
                text: "Static"
                color: staticButton.selected ? Theme.onAccentColor : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: staticButton.hovered ? Font.DemiBold : Font.Normal
                scale: staticButton.hovered ? 1.06 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: staticButton.hovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: staticButton.hovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                    }
                }
            }

            MouseArea {
                id: staticHit
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.interactionReady
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (kindSwitch.hoveredKind === "") kindSwitch.hoveredKind = "static"
                }
                onExited: {
                    if (kindSwitch.hoveredKind === "static")
                        kindSwitch.hoveredKind = livelyHit.containsMouse ? "lively" : ""
                }
                onClicked: root.switchKind("static")
            }

            Behavior on x { NumberAnimation { duration: staticButton.motionDuration } }
            Behavior on y { NumberAnimation { duration: staticButton.motionDuration } }
            Behavior on width { NumberAnimation { duration: staticButton.motionDuration } }
            Behavior on height { NumberAnimation { duration: staticButton.motionDuration } }
        }

        Item {
            id: livelyButton
            x: kindSwitch.hitPadding + kindSwitch.laneWidth + (kindSwitch.laneWidth - width) / 2
            y: kindSwitch.hitPadding + (kindSwitch.trackHeight - height) / 2
            width: (kindSwitch.laneWidth + (selected ? kindSwitch.selectedOverflow * 2 : 0))
                   * (hovered ? 1.11 : 1)
            height: (kindSwitch.trackHeight + (selected ? kindSwitch.selectedOverflow * 2 : 0))
                    * (hovered ? 1.11 : 1)
            z: hovered ? 40 : (root.activeKind === "lively" ? 30 : 20)
            readonly property bool hovered: kindSwitch.hoveredKind === "lively"
            readonly property bool selected: root.activeKind === "lively"
            readonly property int motionDuration: hovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Theme.accent
                opacity: livelyButton.selected ? 1 : (livelyButton.hovered ? 0.34 : 0)
            }

            Text {
                anchors.centerIn: parent
                text: "Lively"
                color: livelyButton.selected ? Theme.onAccentColor : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: livelyButton.hovered ? Font.DemiBold : Font.Normal
                scale: livelyButton.hovered ? 1.06 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: livelyButton.hovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: livelyButton.hovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                    }
                }
            }

            MouseArea {
                id: livelyHit
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.interactionReady
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (kindSwitch.hoveredKind === "") kindSwitch.hoveredKind = "lively"
                }
                onExited: {
                    if (kindSwitch.hoveredKind === "lively")
                        kindSwitch.hoveredKind = staticHit.containsMouse ? "static" : ""
                }
                onClicked: root.switchKind("lively")
            }

            Behavior on x { NumberAnimation { duration: livelyButton.motionDuration } }
            Behavior on y { NumberAnimation { duration: livelyButton.motionDuration } }
            Behavior on width { NumberAnimation { duration: livelyButton.motionDuration } }
            Behavior on height { NumberAnimation { duration: livelyButton.motionDuration } }
        }
    }

    Text {
        anchors.centerIn: parent
        z: 200
        visible: root.items.length === 0
        text: root.loadError.length > 0
              ? root.loadError
              : (root.activeKind === "lively" ? "No lively wallpapers" : "No static wallpapers")
        color: Theme.fgMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

}
