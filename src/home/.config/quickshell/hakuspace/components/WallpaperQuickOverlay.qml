import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "wallpaper" as Wallpaper

PanelWindow {
    id: root
    required property var modelData
    // Workspace inherits the same host and visual lifetime contract.
    property string presentation: "quick"
    readonly property bool panelOpen: UiState.activePanel === "wallpaper"
        && UiState.wallpaperPresentation === presentation && UiState.wallpaperScreenName === modelData.name
    readonly property bool closing: panelOpen && UiState.wallpaperCloseRequested
    readonly property bool releaseReady: !panelOpen && expansion === 0 && !motion.running && !fold.running && !quickExit.running && !quickRestore.running
    readonly property Item browserItem: browser
    property real expansion: 0
    property real stackSpread: 1
    // Quick closing keeps the pulse, zoom and final fade independently reversible.
    property real selectedPulse: 1
    property real quickOpacity: 0
    // Opening starts at sixty percent; closing can continue all the way to zero.
    property real quickScale: 0.6
    property bool introStarted: false
    // A configured first buffer precedes motion and native resource uploads.
    property bool surfacePresented: false
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: panelOpen || expansion > 0 || quickOpacity > 0
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-wallpaper-" + presentation
    WlrLayershell.keyboardFocus: panelOpen && !closing && UiState.ownsInteraction("wallpaper", modelData.name)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        item: root.presentation === "quick" ? browser.quickInputItem : browser.topInputItem
        width: root.panelOpen && !root.closing ? item.width : 0
        height: root.panelOpen && !root.closing ? item.height : 0
        Region {
            item: browser.bottomInputItem
            width: root.presentation === "workspace" && root.panelOpen && !root.closing ? item.width : 0
            height: root.presentation === "workspace" && root.panelOpen && !root.closing ? item.height : 0
        }
        Region {
            item: browser.settingsInputItem
            width: root.panelOpen && !root.closing && item.visible ? item.width : 0
            height: root.panelOpen && !root.closing && item.visible ? item.height : 0
        }
        Region {
            item: browser.selectedInputItem
            width: root.panelOpen && !root.closing && item ? item.width : 0
            height: root.panelOpen && !root.closing && item ? item.height : 0
        }
    }

    // Pulse immediately alongside the fold and connect their shared finish to zoom.
    function animate() {
        var opening = panelOpen && !closing
        if (!opening && quickExit.running) return
        motion.stop()
        fold.stop()
        quickExit.stop()
        quickRestore.stop()
        motion.duration = presentation === "workspace" ? HAnimation.slow : HAnimation.effects
        motion.easing.bezierCurve = presentation === "workspace" ? HAnimation.tooltipCurve : HAnimation.moduleCurve
        if (opening) {
            motion.to = 1
            if (expansion !== 1) {
                if (expansion === 0) tryOpen()
                else motion.start()
            }
            fold.to = 1
            if (stackSpread !== 1) fold.start()
            if (presentation === "quick" && expansion > 0) quickRestore.start()
            browser.resumeIntro()
            tryIntro()
        } else {
            browser.pauseIntro()
            closeContent()
        }
    }
    // Cold presentations wait for geometry, the initial frame and thumbnail decodes.
    function tryOpen() {
        if (!panelOpen || closing || expansion !== 0 || motion.running
                || !surfacePresented || !modelData || width !== modelData.width || height !== modelData.height
                || !browser.openingReady) return
        motion.to = 1
        motion.start()
        if (presentation === "quick") quickRestore.start()
    }
    Connections {
        target: root.contentItem.Window.window
        enabled: !root.surfacePresented
        function onFrameSwapped() {
            if (root.width === root.modelData.width && root.height === root.modelData.height) {
                root.surfacePresented = true
                root.tryOpen()
            }
        }
    }
    // Start the full turn during reveal once the drawing plane is configured.
    function tryIntro() {
        if (!modelData || presentation !== "quick" || introStarted || !panelOpen || closing || expansion <= 0
                || width !== modelData.width || height !== modelData.height) return
        introStarted = true
        browser.playIntro()
    }
    onWidthChanged: tryIntro()
    onHeightChanged: tryIntro()
    onExpansionChanged: tryIntro()
    function closeContent() {
        if (quickExit.running) return
        if (presentation === "quick" && (expansion > 0 || quickOpacity > 0)) {
            quickExit.start()
            return
        }
        motion.to = 0
        if (expansion > 0) motion.start()
        else if (closing) Qt.callLater(root.finishClose)
    }
    // Defer a pre-frame dismissal beyond the closing binding; reopening cancels it.
    function finishClose() {
        if (closing && expansion === 0 && !motion.running && !fold.running && !quickExit.running && !quickRestore.running)
            UiState.finishCloseWallpaper(modelData.name)
    }
    onPanelOpenChanged: animate()
    onClosingChanged: animate()
    Component.onCompleted: animate()
    // A retired presentation must never dismiss its replacement on this output.
    Component.onDestruction: {
        if (!ShellTransitionState.chromeEnabled || !Quickshell.screens.includes(modelData))
            UiState.forceCloseWallpaperIfScreen(modelData.name)
    }
    NumberAnimation {
        id: fold
        target: root; property: "stackSpread"
        duration: HAnimation.effects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.moduleCurve
    }
    NumberAnimation {
        id: motion
        target: root; property: "expansion"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (root.closing) root.finishClose()
            else root.tryIntro()
        }
    }
    // Reopening restores the current opacity and pulse without snapping either value.
    ParallelAnimation {
        id: quickRestore
        NumberAnimation {
            target: root; property: "quickOpacity"; to: 1
            duration: HAnimation.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
        NumberAnimation {
            target: root; property: "selectedPulse"; to: 1
            duration: HAnimation.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
        NumberAnimation {
            target: root; property: "quickScale"; to: 1
            duration: HAnimation.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
    }
    SequentialAnimation {
        id: quickExit
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "stackSpread"; to: 0
                duration: HAnimation.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.65, 0, 0.85, 0.1, 1, 1]
            }
            SequentialAnimation {
                NumberAnimation {
                    target: root; property: "selectedPulse"; to: 1.07
                    duration: HAnimation.fast / 2
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.moduleCurve
                }
                NumberAnimation {
                    target: root; property: "selectedPulse"; to: 1
                    duration: HAnimation.normal - HAnimation.fast / 2
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.4, 0, 1, 1, 1, 1]
                }
            }
        }
        NumberAnimation {
            target: root; properties: "expansion,quickScale"; to: 0.4
            duration: HAnimation.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 0.1, 0.7, 0.7, 1, 1]
        }
        // Matching zoom tangents keep shrinking continuous when the fade begins.
        ParallelAnimation {
            NumberAnimation {
                target: root; properties: "expansion,quickScale"; to: 0
                duration: HAnimation.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.25, 0.6, 0.45, 1, 1, 1]
            }
            NumberAnimation {
                target: root; property: "quickOpacity"; to: 0
                duration: HAnimation.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.moduleCurve
            }
        }
        onFinished: root.finishClose()
    }
    // A click restores the wallpaper keyboard lease after interaction with a pinned note.
    MouseArea {
        anchors.fill: parent
        z: 10000
        enabled: root.panelOpen && !root.closing
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            UiState.claimInteraction("wallpaper", root.modelData.name)
            browser.forceActiveFocus()
            mouse.accepted = false
        }
    }
    Wallpaper.WallpaperBrowser {
        id: browser
        anchors.fill: parent
        presentation: root.presentation
        refreshOnShow: false
        reveal: root.expansion
        contentOpacity: root.presentation === "quick" ? root.quickOpacity : root.expansion
        spread: root.stackSpread
        selectedPulse: root.selectedPulse
        scale: root.presentation === "quick" ? root.quickScale : 1
        enabled: root.panelOpen && !root.closing
        focus: enabled
        onEnabledChanged: if (enabled) forceActiveFocus()
        Component.onCompleted: if (enabled) forceActiveFocus()
        onOpeningReadyChanged: root.tryOpen()
        onCloseRequested: UiState.closeWallpaper()
        onSettingsRequested: {
            UiState.settingsGroup = "Wallpaper"
            UiState.openSettings(root.modelData.name)
        }
    }
}
