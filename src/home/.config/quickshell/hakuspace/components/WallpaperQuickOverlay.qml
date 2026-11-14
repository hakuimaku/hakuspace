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
    readonly property bool switchingToWorkspace: presentation === "quick"
        && UiState.activePanel === "wallpaper" && UiState.wallpaperPresentation === "workspace"
        && UiState.wallpaperScreenName === modelData.name
    readonly property bool releaseReady: !panelOpen && expansion === 0 && workspaceButtonReveal === 0
        && !motion.running && !fold.running && !quickExit.running && !quickRestore.running
        && !workspaceMorphExit.running && !buttonAnim.running
    readonly property Item browserItem: browserLoader.item
    readonly property var browser: browserLoader.item
    readonly property bool leftWorkspace: presentation === "workspace" && ChromeLayout.leftBarMode
    // Side-card masks are clipped to the gallery instead of capturing hidden PathView tails.
    function cardInputRect(index) {
        return leftWorkspace && browser && browser.cardInputRects.length > index ? browser.cardInputRects[index] : {x: 0, y: 0, width: 0, height: 0}
    }
    property real expansion: 0
    property real stackSpread: 1
    // Quick closing keeps the pulse, zoom and final fade independently reversible.
    property real selectedPulse: 1
    property real quickOpacity: 0
    // Opening starts at sixty percent; closing can continue all the way to zero.
    property real quickScale: 0.6
    // Mode 1 -> Mode 2 morph progress and diagonal top-right button slide progress.
    property real workspaceMorph: 0
    property real workspaceButtonReveal: 0
    property bool introStarted: false
    // A configured first buffer precedes motion and native resource uploads.
    property bool surfacePresented: false
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: panelOpen || expansion > 0 || quickOpacity > 0 || workspaceButtonReveal > 0
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-wallpaper-" + presentation
    WlrLayershell.keyboardFocus: panelOpen && !closing && UiState.ownsInteraction("wallpaper", modelData.name)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property bool inputActive: panelOpen && !closing && !!browser
    mask: Region {
        width: root.presentation === "quick" && root.panelOpen && !root.closing ? root.modelData.width : 0
        height: root.presentation === "quick" && root.panelOpen && !root.closing ? root.modelData.height : 0
        item: root.inputActive && root.presentation === "workspace" ? browser.topInputItem : null
        Region {
            item: root.inputActive && root.presentation === "workspace" && !root.leftWorkspace ? browser.bottomInputItem : null
        }
        Region {
            item: root.inputActive && root.leftWorkspace ? browser.mediaInputItem : null
        }
        Region {
            item: root.inputActive && root.leftWorkspace ? browser.categoryInputItem : null
        }
        Region {
            item: root.inputActive && browser.settingsInputItem.visible ? browser.settingsInputItem : null
        }
        Region {
            item: root.inputActive && !root.leftWorkspace ? browser.selectedInputItem : null
        }
        Region {
            x: root.cardInputRect(0).x; y: root.cardInputRect(0).y
            width: root.inputActive ? root.cardInputRect(0).width : 0
            height: root.inputActive ? root.cardInputRect(0).height : 0
        }
        Region {
            x: root.cardInputRect(1).x; y: root.cardInputRect(1).y
            width: root.inputActive ? root.cardInputRect(1).width : 0
            height: root.inputActive ? root.cardInputRect(1).height : 0
        }
        Region {
            x: root.cardInputRect(2).x; y: root.cardInputRect(2).y
            width: root.inputActive ? root.cardInputRect(2).width : 0
            height: root.inputActive ? root.cardInputRect(2).height : 0
        }

    }

    function startButtonAnim(opening) {
        buttonAnim.stop()
        buttonAnim.to = opening ? 1 : 0
        buttonAnim.duration = opening ? 460 : 420
        buttonAnim.easing.bezierCurve = opening
            ? [0.22, 1.06, 0.32, 1.0, 1, 1]
            : HAnimation.sidebarCloseCurve
        buttonAnim.start()
    }
    // Pulse immediately alongside the fold and connect their shared finish to zoom.
    function animate() {
        if (!browser) return
        var opening = panelOpen && !closing
        if (!opening && (quickExit.running || workspaceMorphExit.running)) return
        motion.stop()
        fold.stop()
        quickExit.stop()
        quickRestore.stop()
        workspaceMorphExit.stop()
        buttonAnim.stop()
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
            if (presentation === "quick" && expansion > 0) {
                quickRestore.start()
                startButtonAnim(true)
            }
            browser.resumeIntro()
            tryIntro()
        } else {
            browser.pauseIntro()
            closeContent()
        }
    }
    // Cold presentations wait for geometry, the initial frame and thumbnail decodes.
    function tryOpen() {
        if (!browser || !panelOpen || closing || expansion !== 0 || motion.running
                || !surfacePresented || !modelData || width !== modelData.width || height !== modelData.height
                || !browser || !browser.openingReady) return
        workspaceMorph = 0
        motion.to = 1
        motion.start()
        if (presentation === "quick") {
            quickRestore.start()
            startButtonAnim(true)
        }
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
        if (browser) browser.playIntro()
    }
    onWidthChanged: tryIntro()
    onHeightChanged: tryIntro()
    onExpansionChanged: tryIntro()
    function closeContent() {
        if (quickExit.running || workspaceMorphExit.running) return
        if (presentation === "quick" && (expansion > 0 || quickOpacity > 0 || workspaceButtonReveal > 0)) {
            startButtonAnim(false)
            if (UiState.activePanel === "wallpaper" && UiState.wallpaperPresentation === "workspace"
                    && !!modelData && UiState.wallpaperScreenName === modelData.name) {
                workspaceMorphExit.start()
                return
            }
            quickExit.start()
            return
        }
        motion.to = 0
        if (expansion > 0) motion.start()
        else if (closing) Qt.callLater(root.finishClose)
    }
    // Defer a pre-frame dismissal beyond the closing binding; reopening cancels it.
    function finishClose() {
        if (closing && expansion === 0 && !motion.running && !fold.running
                && !quickExit.running && !quickRestore.running && !workspaceMorphExit.running && !buttonAnim.running)
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
        NumberAnimation {
            target: root; property: "workspaceMorph"; to: 0
            duration: HAnimation.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
    }
    NumberAnimation {
        id: buttonAnim
        target: root; property: "workspaceButtonReveal"
        duration: 460
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1.06, 0.32, 1.0, 1, 1]
    }
    // When switching to Mode 2, morph the Mode 1 carousel down to the workspace rail while controls peel away.
    ParallelAnimation {
        id: workspaceMorphExit
        NumberAnimation {
            target: root; property: "workspaceMorph"; to: 1
            duration: HAnimation.actionLayerOpenDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerMorphCurve
        }
        NumberAnimation {
            target: root; property: "stackSpread"; to: ChromeLayout.leftBarMode ? 0.9 : 1.35
            duration: HAnimation.actionLayerOpenDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerMorphCurve
        }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation {
                target: root; property: "quickOpacity"; to: 0
                duration: 380
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.actionLayerContentCurve
            }
        }
        onFinished: {
            if (!root.panelOpen) {
                root.expansion = 0
                root.quickOpacity = 0
                root.workspaceButtonReveal = 0
            }
            root.finishClose()
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
    // Only one renderer owns carousel delegates and thumbnail demand at a time.
    Loader {
        id: browserLoader
        focus: true
        anchors.fill: parent
        sourceComponent: root.leftWorkspace ? leftWorkspaceComponent : standardComponent
        onLoaded: root.animate()
    }
    Component {
        id: standardComponent
        Wallpaper.WallpaperBrowser {
            id: standardBrowser
            anchors.fill: parent
            presentation: root.presentation
            refreshOnShow: false
            reveal: root.expansion
            contentOpacity: root.presentation === "quick" ? root.quickOpacity : root.expansion
            spread: root.stackSpread
            selectedPulse: root.selectedPulse
            workspaceMorph: root.presentation === "quick" ? root.workspaceMorph : 0
            workspaceButtonReveal: root.presentation === "quick" ? root.workspaceButtonReveal : 0
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
    Component {
        id: leftWorkspaceComponent
        Wallpaper.WorkspaceLeftLayout {
            reveal: root.expansion
            contentOpacity: root.expansion
            spread: root.stackSpread
            screenName: root.modelData.name
            enabled: root.panelOpen && !root.closing
            focus: enabled
            onOpeningReadyChanged: root.tryOpen()
            onCloseRequested: UiState.closeWallpaper()
            onSettingsRequested: {
                UiState.settingsGroup = "Wallpaper"
                UiState.openSettings(root.modelData.name)
            }
        }
    }
}
