import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    // Exercise every font, palette and artwork combination on the real native overlay.
    property var windows: []
    property int step: 0
    property int phase: 0
    property int ticks: 0
    property int settledTicks: 0
    property string label: ""
    property var records: []
    property bool baseline: Quickshell.env("HAKUSPACE_LEFTBAR_VISUAL_BASELINE") === "1"
    Component.onDestruction: WallpaperService.shutdown()
    function check(ok, message) {
        if (ok) return
        console.error("Leftbar failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (var child of item.children || []) { var result = find(child, name); if (result) return result }
        return null
    }
    Variants {
        model: Quickshell.screens
        Item {
            id: output
            required property var modelData
            // A contrasting fixture exposes dark cradle edges on otherwise empty headless outputs.
            PanelWindow {
                screen: output.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                visible: !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
                color: Quickshell.env("HAKUSPACE_LEFTBAR_WALLPAPER_BACKGROUND") || (Theme.isLight ? "#d2dce4" : "#385568")
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: 0
                WlrLayershell.layer: WlrLayer.Background
                mask: Region {}
            }
            WallpaperQuickOverlay { id: overlay; modelData: output.modelData; presentation: "workspace" }
            Component.onCompleted: root.windows.push(overlay)
        }
    }
    Process { id: screenshot }
    // Changing fixtures closes through the normal animation before reusing the host.
    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            root.check(++root.ticks < 350, "bounded wallpaper visual matrix timeout")
            if (!ShellSettingsStore.ready || !root.windows.length || screenshot.running) return
            var window = root.windows[0]
            if (root.phase === 0) {
                ShellSettingsStore.setValue("chrome", "statusEdge", "left")
                Theme.fontSize = root.step % 2 ? 21 : 14
                ShellSettingsStore.setValue("appearance", "colorMode", Math.floor(root.step / 2) % 2 ? "light" : "dark")
                var art = root.step < 4 ? "white" : "gradient"
                root.label = window.modelData.width + "x" + window.modelData.height + "-font" + Theme.fontSize + "-" + Theme.colorMode + "-" + art
                var thumbnail = Quickshell.env("HAKUSPACE_LEFTBAR_FIXTURE").replace("preview.png", art + ".png")
                root.records = Array.from({length: 9}, (_, index) => ({path: "visual-" + index,
                    label: "Wallpaper " + index, kind: "static", category: ["Animated", "Graphite Mono", "monochrome", "others"][index % 4], thumbnail: thumbnail}))
                WallpaperLibrary.items = root.records
                WallpaperLibrary.initialized = true
                WallpaperLibrary.selectIndex(4)
                UiState.openWallpaperWorkspace(window.modelData.name)
                root.settledTicks = 0
                root.phase = 1
            } else if (root.phase === 1) {
                if (window.expansion < 1 || !window.browserItem || !window.browserItem.openingReady) return
                var browser = window.browserItem
                var reel = root.find(browser, "wallpaperReel")
                if (!reel.count) { WallpaperLibrary.items = root.records; WallpaperLibrary.selectIndex(4); return }
                if (!reel.currentItem) return
                // Capture settled control colors after the native host finishes opening.
                if (++root.settledTicks < 3) return
                var cards = reel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible).map(item => {
                    var a = item.mapToItem(browser, 0, 0), b = item.mapToItem(browser, item.width, item.height)
                    return {chosen: item.chosen, x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y}
                })
                root.check(cards.length === 3, "three upright cards in " + root.label)
                for (var card of cards) root.check(card.x >= ScreenGeometry.contentLeftEdge && card.y >= ScreenGeometry.topBorderThickness
                    && card.x + card.width <= window.width + 1
                    && card.y + card.height <= window.height - ScreenGeometry.bottomReservation(window.modelData.name) + 1,
                    "native artwork bounds in " + root.label)
                if (!root.baseline) {
                    var layout = browser.sideGeometry
                    root.check(layout.infoSurfaceRect.y + layout.infoSurfaceRect.height + Theme.gap <= layout.galleryRect.y,
                        "information ends above gallery in " + root.label)
                    root.check(Math.abs(layout.railRect.y + layout.railRect.height - layout.galleryRect.y) < 1,
                        "selector content meets the gallery in " + root.label)
                }
                console.info("Wallpaper visual " + JSON.stringify({label: root.label, layout: browser.sideGeometry, cards: cards,
                    reservation: ScreenGeometry.bottomReservation(window.modelData.name)}))
                screenshot.command = ["grim", "-o", window.modelData.name,
                    Quickshell.env("HAKUSPACE_LEFTBAR_ARTIFACT_DIR") + "/" + root.label + ".png"]
                screenshot.running = true
                root.phase = 2
            } else if (root.phase === 2) {
                UiState.closeWallpaper()
                root.phase = 3
            } else if (root.phase === 3) {
                if (!window.releaseReady) return
                if (++root.step < 8) root.phase = 0
                else { console.info("Leftbar runtime checks passed"); Qt.quit() }
            }
        }
    }
}
