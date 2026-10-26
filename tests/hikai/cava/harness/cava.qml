import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"
import "components"
import "components/base" as Base

ShellRoot {
    id: root
    // Exercise every edge and chassis combination through the production loader.
    property var cases: [[true, false], [false, true], [true, true], [false, false], [true, false], [false, true]]
    property int caseIndex: 0
    property int phase: -1
    property int ticks: 0
    // Count construction separately from animation state to catch close/reopen churn.
    property int births: 0
    property int deaths: 0
    property bool sawOpen: false
    property bool sawClose: false
    // Retain only dimensions while checking that animation never resizes the host.
    property var hostSize: null
    readonly property var cava: lifetime.active ? lifetime.item : null

    // Turn behavioral failures into a failing runner exit status.
    function check(condition, message) {
        if (condition) return
        console.error("Hikai Cava attachment failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }

    // Locate the real window without adding test-only API to the component.
    function window() {
        return cava.data.find(child => child.contentItem !== undefined)
    }

    // Start a fresh owner with the requested edge, font metrics and wave height.
    function openCase() {
        AppState.cavaTopState = cases[caseIndex][0]
        AppState.taskbarManualState = cases[caseIndex][1]
        AppState.cavaColorMode = caseIndex % 3 === 0 ? "surface" : "accent"
        CavaService.height = 72 + caseIndex * 16
        var draft = ShellSettingsStore.defaults()
        draft.appearance.colorMode = caseIndex % 2 === 0 ? "dark" : "light"
        draft.appearance.surfaceTone = caseIndex % 3 === 0 ? "ink" : caseIndex % 3 === 1 ? "dark" : "soft"
        ShellSettingsStore.values = draft
        CavaService.style = caseIndex % 3 === 0 ? "capsule" : "liquid"
        Theme.fontSize = 14 + caseIndex * 2
        hostSize = null
        sawOpen = false
        sawClose = false
        CavaService.enabled = true
        phase = 0
    }

    // Retain the Niri backing geometry checks while testing the animated inner content.
    function checkGeometry() {
        var host = window()
        var body = host.contentItem.children[0].children[0]
        var surface = body.children[0]
        var wave = body.children[1]
        // QML int properties truncate fractional font-derived attachment heights.
        var inset = Math.floor(AppState.cavaTopState
            ? (ChromeLayout.taskbarMode ? ScreenGeometry.topBorderThickness : Theme.topBarHeight)
            : (ChromeLayout.taskbarMode ? ScreenGeometry.taskbarReservation() : ScreenGeometry.bottomInset))
        check(body.y === 0, "fully open content reaches its attachment")
        check(host.margins.top === 0 && host.margins.bottom === 0, "host reaches the screen edge")
        check(host.margins.left === 0 && host.margins.right === 0, "surface spans the output")
        check(surface.height === inset, "surface matches the reserved chassis in case " + root.caseIndex + ": " + surface.height + " vs " + inset)
        check(surface.color.toString() === CavaService.underbarColor.toString(), "surface follows the Cava color mode")
        check(Math.abs(surface.y - (AppState.cavaTopState ? 0 : wave.height)) < 0.01, "surface follows the selected edge")
        check(Math.abs(wave.y - (AppState.cavaTopState ? inset : 0)) < 0.01, "wave retains its baseline")
        check(Math.abs(wave.height - CavaService.height - CavaService.ceilingHeadroom) < 0.01, "wave retains its height")
        check(wave.x === 0 && wave.width === host.width, "wave extends across the Rounded Screen side rails")
        var visual = wave.children[0].item
        if (visual.inkOpacity !== undefined) {
            check(visual.inkOpacity === 1 && visual.crestOpacity === 1, "wave body and crest are opaque")
            check(String(visual.crestColor) === String(visual.inkColor), "wave crest matches its body")
        } else check(visual.barOpacity === 1, "capsules match the opaque attachment")
        check(host.exclusionMode === ExclusionMode.Ignore && host.exclusiveZone === 0, "no duplicate reservation")
        check(host.WlrLayershell.layer === WlrLayer.Bottom, "surface follows the Cava layer")
        check(host.mask.regions.length === 0 && host.mask.width === 0 && host.mask.height === 0, "surface remains click-through")
    }

    Base.LifecycleLoader {
        id: lifetime
        requested: CavaService.enabled && CavaService.available
        onItemChanged: if (item) root.check(item.reveal < 1, "new owner starts outside the screen")
        CavaUnderbarWindow {
            modelData: Quickshell.screens[0]
            Component.onCompleted: ++root.births
            Component.onDestruction: ++root.deaths
        }
    }

    FrameAnimation {
        running: !!root.cava
        onTriggered: {
            var host = root.window()
            var clip = host.contentItem.children[0]
            var body = clip.children[0]
            if (host.width !== Quickshell.screens[0].width) return
            if (!root.hostSize) root.hostSize = [host.width, host.height]
            root.check(host.width === root.hostSize[0] && host.height === root.hostSize[1],
                "slide keeps Wayland geometry stable: " + [host.width, host.height] + "/" + root.hostSize)
            root.check(clip.clip, "content outside the host stays clipped")
            if (root.cava.reveal > 0 && root.cava.reveal < 1) {
                root.check(AppState.cavaTopState ? body.y < 0 : body.y > 0, "slide follows the selected screen edge")
                root.check(host.visible && !root.cava.releaseReady, "unfinished motion retains the owner")
                if (CavaService.enabled) root.sawOpen = true
                else root.sawClose = true
            }
        }
    }

    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 600, "animation timeout in phase " + root.phase)
            if (root.phase < 0) {
                if (!ShellSettingsStore.ready) return
                CavaService.process.command = ["sleep", "60"]
                CavaService._smoothedBars = new Array(CavaService.barCount).fill(0)
                root.check(!lifetime.active, "disabled Cava owns no surface")
                root.openCase()
            } else if (root.phase === 0 && root.cava && root.cava.reveal === 1) {
                root.check(root.sawOpen, "new owner slides into view")
                root.checkGeometry()
                CavaService.enabled = false
                root.phase = 1
            } else if (root.phase === 1 && root.sawClose) {
                var owner = root.cava
                var offset = root.window().contentItem.children[0].children[0].y
                AppState.cavaColorMode = AppState.cavaColorMode === "surface" ? "accent" : "surface"
                CavaService.enabled = true
                root.check(root.cava === owner && root.window().contentItem.children[0].children[0].y === offset,
                    "reopening reverses continuously without replacing the owner")
                root.phase = 2
            } else if (root.phase === 2 && root.cava.reveal === 1) {
                root.check(root.births === root.caseIndex + 1 && root.deaths === root.caseIndex, "reopening does not rebuild Cava")
                root.checkGeometry()
                CavaService.enabled = false
                root.phase = 3
            } else if (root.phase === 3 && !lifetime.active) {
                root.check(root.deaths === root.births, "completed close releases the window")
                if (++root.caseIndex < root.cases.length) root.openCase()
                else {
                    console.log("Hikai Cava attachment checks passed")
                    Qt.quit()
                }
            }
        }
    }
}
