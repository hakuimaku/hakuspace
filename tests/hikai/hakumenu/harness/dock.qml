import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"
import "components/flare" as Flare

ShellRoot {
    id: root
    // Exercise generic bottom geometry and repeated ownership changes on both outputs.
    property var surfaces: []
    property var target: null
    property int phase: 0
    property int cycles: 0
    property int ticks: 0
    readonly property bool reduced: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    function check(ok, message) {
        if (ok) return
        console.error("Dock flare failed: phase=" + phase + " cycle=" + cycles + " " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        if (item.active === true && item.item) { var result = find(item.item, predicate); if (result) return result }
        var children = item.contentItem ? item.contentItem.data : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var child of children) { var result = find(child, predicate); if (result) return result }
        return null
    }
    function open() {
        var height = target.modelData.height
        UiState.openHakuMenu(target.modelData.name, "drun", "dockbar",
            {x: 40, y: height - 60, width: 48, height: 48})
    }
    function assertOpen() {
        check(UiState.activePanel === "hakumenu" && UiState.hakuMenuScreenName === target.modelData.name
            && UiState.hakuMenuStyle === "bottomFlare" && UiState.hakuMenuSource === "dockbar", "state ownership")
        check(target.menu.loadedCount === 1 && target.menu.panelOpen, "exactly one open loader")
        check(UiState.ownsInteraction("hakumenu", target.modelData.name), "interaction owner")
        var host = find(target.menu, item => item.bottomAttached === true)
        check(host.menuTop === ScreenGeometry.bottomHostTop(target.modelData.height),
            "Dock seam excludes frame and host reservation")
        return !!find(target.menu, item => item.objectName === "hakumenu-searchInput" && item.activeFocus)
    }
    // Keep a virtual seat available without sending incidental pointer movement.
    Process { command: ["python3", Quickshell.env("HAKUSPACE_TEST_KEYBOARD")]; running: true; stdinEnabled: true }
    Flare.FlareMorph {
        id: ordinary
        anchorRect: ({x: 640, y: 0, width: 0, height: 0})
        hostRect: ({x: 0, y: 0, width: 1280, height: 720})
        bounds: ({start: 0, end: 1280})
        contentW: 512; contentH: 288; padX: 0; padY: 0; minW: 0; maxW: 800; snap: 0
        openDuration: root.reduced ? 0 : 160
        closeDuration: root.reduced ? 0 : 160
    }
    Variants {
        model: Quickshell.screens
        Item {
            id: surface
            required property var modelData
            property alias menu: menu
            HakuMenuPanel {
                id: menu
                modelData: surface.modelData
                onLoadedCountChanged: root.check(loadedCount <= 1, "presentation transfer never loads two edges")
            }
            Component.onCompleted: root.surfaces.push(this)
        }
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            root.check(++root.ticks < 2400, "timeout")
            if (root.surfaces.length < 2) return
            if (root.phase === 0) {
                ChromeLayout.topBarMode = true
                ChromeLayout.dockbarActive = true
                ordinary.shown = true
                ordinary.updateTargetBounds()
                root.check(ordinary.mStart === 384 && ordinary.mEnd === 896, "default opening keeps established immediate width")
                root.phase = 1
            } else if (root.phase === 1) {
                if (Math.abs(ordinary.mHeight - 288) > 0.01) return
                root.phase = 2
                ordinary.shown = false
                if (!root.reduced) root.check(ordinary.mStart === 384 && ordinary.mEnd === 896, "default closing keeps width while height collapses")
            } else if (root.phase === 2) {
                if (ordinary.mHeight > 0.01) return
                root.target = root.surfaces[0]
                root.open()
                root.phase = 3
            } else if (root.phase === 3) {
                if (!root.assertOpen()) return
                UiState.closeHakuMenu()
                if (root.cycles % 2) Qt.callLater(root.open)
                else root.open()
                root.phase = 4
            } else if (root.phase === 4) {
                if (!root.assertOpen()) return
                console.info("Dock reopen evidence " + JSON.stringify({cycle: root.cycles, reduced: root.reduced,
                    output: UiState.hakuMenuScreenName, style: UiState.hakuMenuStyle, source: UiState.hakuMenuSource,
                    loaded: root.target.menu.loadedCount, open: root.target.menu.panelOpen}))
                UiState.closeHakuMenu()
                root.phase = 5
            } else if (root.phase === 5) {
                if (root.target.menu.loadedCount) return
                root.check(!UiState.hakuMenuSource, "closed session clears source")
                if (++root.cycles === 10) {
                    UiState.openHakuMenu(root.target.modelData.name, "drun", "default")
                    root.phase = 6
                    return
                }
                root.target = root.surfaces[root.cycles % 2]
                root.open()
                root.phase = 3
            } else if (root.phase === 6) {
                if (!root.target.menu.panelOpen) return
                root.check(UiState.hakuMenuStyle === "topFlare" && root.target.menu.loadedCount === 1, "Dock topology also supports the top edge")
                root.open()
                root.phase = 7
            } else if (root.phase === 7) {
                if (!root.target.menu.panelOpen || !root.assertOpen()) return
                UiState.openHakuMenu(root.target.modelData.name, "drun", "default")
                root.phase = 8
            } else if (root.phase === 8) {
                if (!root.target.menu.panelOpen) return
                root.check(UiState.hakuMenuStyle === "topFlare", "bottom-to-top transfer")
                console.info("HakuMenu Mini passed: 10 bottom open-close-immediate-reopen cycles; default morph; edge transfers")
                Qt.quit()
            }
        }
    }
}
