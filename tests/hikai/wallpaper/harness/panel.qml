import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"
import "components/base" as Base

ShellRoot {
    id: root
    // Test both status-bar layouts without constructing unrelated shell components.
    property int layout: 0
    property int phase: 0
    property int ticks: 0
    property int births: 0
    property int deaths: 0
    property bool sawOpening: false
    property bool sawClosing: false
    property var size: null
    readonly property var panel: lifetime.active ? lifetime.item : null
    readonly property var output: Quickshell.screens[0]
    readonly property string artifacts: Quickshell.env("HAKUSPACE_WALLPAPER_PANEL_ARTIFACT_DIR")
    // Reload once during dismissal to catch stale animation callbacks and surface owners.
    PersistentProperties {
        id: reloadMemory
        reloadableId: "wallpaper-panel-slide-regression"
        property bool closingReload: false
        onLoaded: if (closingReload) root.phase = 7
    }

    // Report a failed frame invariant with its current motion phase.
    function check(condition, message) {
        if (condition) return
        console.error("Wallpaper panel slide failed at " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }

    // Find a visual descendant without adding test-only properties to production code.
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children || []) {
            var result = find(child, name)
            if (result) return result
        }
        return null
    }

    // Check real Taskbar controls rather than only the wallpaper state flag.
    function checkTaskbarRight(shown) {
        var host = taskbar.data.find(child => child.bottomChromeHost === true)
        var modules = host.contentItem.children.find(child => child.presentation === "fullBottom")
        var right = find(modules, "rightStatusModules")
        check(right.visible === shown && right.enabled === shown, "Taskbar right modules follow their wallpaper output")
        check(find(modules, "leftStatusModules").visible, "Taskbar left modules remain visible")
    }

    // Each new sidebar must enter from the physical right edge.
    function open() {
        AppState.taskbarManualState = layout === 1
        size = null
        sawOpening = false
        sawClosing = false
        UiState.openWallpaper(output.name)
    }

    PanelWindow {
        screen: root.output
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore
        color: "#5a7490"
    }
    Taskbar { id: taskbar; modelData: root.output }
    Base.LifecycleLoader {
        id: lifetime
        requested: UiState.activePanel === "wallpaper" && UiState.wallpaperScreenName === root.output.name
        WallpaperBrowserPanel {
            modelData: root.output
            Component.onCompleted: ++root.births
            Component.onDestruction: ++root.deaths
        }
    }
    Process {
        id: capture
        onExited: code => root.check(code === 0, "capture the compositor output")
    }

    FrameAnimation {
        running: !!root.panel
        onTriggered: {
            if (root.panel.width !== root.output.width || !root.panel.browserItem) return
            var browser = root.panel.browserItem
            var body = browser.parent.parent
            if (!root.size) root.size = [root.panel.width, root.panel.height, browser.width, browser.height]
            root.check(root.panel.width === root.size[0] && root.panel.height === root.size[1], "Wayland host size stays fixed")
            root.check(browser.width === root.size[2] && browser.height === root.size[3], "browser layout stays fixed")
            root.check(body.width === root.panel.browserWidth, "sidebar translates without resizing its clip")
            root.check(browser.opacity === 1 && browser.parent.opacity === 1 && browser.reveal === 1, "slide does not fade the thumbnail subtree")
            root.check(root.panel.expansion >= 0 && root.panel.expansion <= 1, "slide has no overshoot")
            if (taskbar.active && root.panel.panelOpen) root.checkTaskbarRight(false)
            var top = root.find(root.panel.contentItem, "wallpaperTopFlare")
            var bottom = root.find(root.panel.contentItem, "wallpaperBottomFlare")
            root.check(top && bottom, "body and flares share one visual tree")
            root.check(top.Window.window === root.panel.contentItem.Window.window
                && bottom.Window.window === top.Window.window, "flares share the same Wayland frame")
            if (root.panel.expansion > 0 && root.panel.expansion < 1) {
                root.check(body.x > root.panel.width - ScreenGeometry.rightInset - root.panel.browserWidth,
                    "intermediate sidebar stays to the right of its final position")
                root.check(root.panel.visible && !root.panel.releaseReady, "moving owner stays alive")
                if (root.panel.closing) root.sawClosing = true
                else root.sawOpening = true
            }
        }
    }

    Timer {
        interval: 20; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 1000, "timeout")
            if (!WallpaperSettingsStore.ready || !ShellSettingsStore.ready || capture.running) return
            if (root.phase === 0) {
                root.check(!lifetime.active, "closed sidebar starts unloaded")
                if (root.layout === 1) {
                    AppState.taskbarManualState = true
                    root.checkTaskbarRight(true)
                }
                root.open()
                root.phase = 1
            } else if (root.phase === 1 && root.panel && root.panel.expansion === 1) {
                root.check(root.sawOpening, "freshly loaded sidebar slides in")
                if (!root.panel.browserItem.interactionReady || root.panel.browserItem.items.length !== 2) return
                root.panel.browserItem.query = "fixture"
                UiState.closeWallpaper()
                root.phase = 2
            } else if (root.phase === 2 && root.sawClosing) {
                var browser = root.panel.browserItem
                var offset = browser.parent.parent.x
                UiState.toggleWallpaper(root.output.name)
                root.check(root.panel.browserItem === browser && browser.parent.parent.x === offset, "interrupted close reverses without a visual jump")
                root.check(browser.query === "fixture", "reversal keeps the browser state")
                root.phase = 3
            } else if (root.phase === 3 && root.panel.expansion === 1) {
                root.check(root.births === root.layout + 1 && root.deaths === root.layout, "reversal reuses its owner")
                capture.command = ["niri", "msg", "action", "screenshot-screen", "--path", root.artifacts + "/open-" + root.layout + ".png", "--show-pointer", "false"]
                capture.running = true
                UiState.closeWallpaper()
                root.phase = 4
            } else if (root.phase === 4 && !lifetime.active) {
                root.check(root.deaths === root.births && UiState.activePanel === "", "completed close releases the surface")
                if (root.layout === 1) {
                    root.checkTaskbarRight(true)
                    UiState.openWallpaper(root.output.name + "-other")
                    root.checkTaskbarRight(true)
                    UiState.finishCloseWallpaper(root.output.name + "-other")
                }
                if (++root.layout < 2) { root.phase = 0; return }
                root.open()
                root.phase = 5
            } else if (root.phase === 5 && root.panel && root.panel.expansion === 1) {
                UiState.activePanel = "settings"
                root.phase = 6
            } else if (root.phase === 6 && !lifetime.active) {
                root.check(UiState.activePanel === "settings", "old sidebar cannot close the next interaction owner")
                root.open()
                root.phase = 8
            } else if (root.phase === 7) {
                root.check(!lifetime.active && UiState.activePanel === "", "reload releases the interrupted owner")
                root.open()
                root.phase = 10
            } else if (root.phase === 8) {
                root.check(UiState.activePanel === "wallpaper", "retired owner cannot close a newly opened sidebar")
                if (root.panel && root.panel.expansion === 1) {
                    UiState.closeWallpaper()
                    root.phase = 9
                }
            } else if (root.phase === 9 && root.panel && root.panel.expansion > 0 && root.panel.expansion < 1) {
                reloadMemory.closingReload = true
                Quickshell.reload(false)
            } else if (root.phase === 10 && root.panel && root.panel.expansion === 1) {
                UiState.closeWallpaper()
                root.phase = 11
            } else if (root.phase === 11 && !lifetime.active) {
                console.info("Wallpaper panel slide checks passed")
                Qt.quit()
            }
        }
    }
}
