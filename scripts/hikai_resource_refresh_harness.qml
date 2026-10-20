import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/dock" as Dock
import "components/hakumenu" as HakuMenu

ShellRoot {
    id: root
    property int phase: 0
    property int ticks: 0
    property bool waiting: false
    property string iconSource: ""
    property string previewVersion: ""
    readonly property string fixture: Quickshell.env("HAKUSPACE_RESOURCE_FIXTURE")
    FloatingWindow {
        visible: true
        implicitWidth: 800
        implicitHeight: 600
        color: "black"
        Dock.DockItem { id: icon; x: 10; y: 10; icon: "probe"; iconSize: 48 }
        HakuMenu.WallpaperCarousel { id: carousel; x: 100; y: 80; width: 680; height: 480; visible: false }
    }
    Process { id: writer; onExited: code => root.check(code === 0, "fixture mutation") }
    // Keep mutations outside the shell implementation and user's real assets.
    function mutate(action) {
        writer.command = ["python3", fixture + "/mutate.py", action]
        writer.running = true
    }
    // Fail on observable stale data rather than relying on fixed process timings.
    function check(ok, message) {
        if (ok) return
        console.error("Hikai resource refresh failed at phase " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Save rendered artwork so the runner can verify decoded pixel colors.
    function capture(name) {
        waiting = true
        check(icon.grabToImage(function(result) {
            root.check(result.saveToFile(root.fixture + "/" + name + ".png"), "capture " + name)
            root.waiting = false
        }), "grab icon")
    }
    Timer {
        interval: 180
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 120, "timeout")
            if (writer.running || root.waiting) return
            if (root.phase === 0) {
                if (!DockApps.iconSources.probe) return
                root.iconSource = DockApps.iconSources.probe
                root.capture("icon-red")
                carousel.visible = true
            } else if (root.phase === 1) {
                if (!carousel.interactionReady) return
                root.check(carousel.staticItems.length === 1 && carousel.livelyItems.length === 0, "initial wallpaper list")
                root.previewVersion = carousel.staticItems[0].previewVersion
                carousel.visible = false
                root.mutate("add")
            } else if (root.phase === 2) {
                carousel.visible = true
            } else if (root.phase === 3) {
                if (!carousel.interactionReady) return
                root.check(carousel.staticItems.length === 2 && carousel.livelyItems.length === 1, "reopen discovers added static and lively files")
                root.check(carousel.staticItems[0].previewVersion !== root.previewVersion, "overwritten preview gets a fresh image version")
                carousel.visible = false
                root.mutate("remove")
            } else if (root.phase === 4) {
                carousel.visible = true
                carousel.visible = false
                carousel.visible = true
            } else if (root.phase === 5) {
                if (!carousel.interactionReady) return
                root.check(carousel.staticItems.length === 1 && carousel.livelyItems.length === 0 && !carousel.refreshPending,
                    "rapid reopen serializes refresh and removes deleted files")
                root.check(carousel.staticItems[0].id === "fresh # image.png", "special filename survives discovery")
                root.check(carousel.fileUrl(carousel.staticItems[0].path).indexOf("%23") >= 0, "preview URL escapes filename fragments")
                carousel.visible = false
                root.mutate("icon-blue")
            } else if (root.phase === 6) {
                if (DockApps.iconSources.probe === root.iconSource) return
                root.iconSource = DockApps.iconSources.probe
            } else if (root.phase === 7) {
                root.capture("icon-blue")
                root.mutate("theme")
            } else if (root.phase === 8) {
                if ((DockApps.iconSources.probe || "").indexOf("/Other/") < 0) return
            } else if (root.phase === 9) {
                root.capture("icon-green")
            } else if (root.phase === 10) {
                root.check(AppState.dockbarManualState, "private Dock state is enabled")
                console.info("Hikai resource refresh checks passed")
                Qt.quit()
            }
            root.phase++
        }
    }
}
