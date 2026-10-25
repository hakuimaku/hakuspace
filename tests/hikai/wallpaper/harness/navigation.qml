import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/wallpaper" as Wallpaper

ShellRoot {
    id: root
    // Native key repeat must move the artwork as well as the selected filename.
    property int phase: 0
    property int ticks: 0
    property int settle: 0
    property int direction: 1
    property int selections: 0
    property real previousOffset: 0
    property real travel: 0
    property bool released: false
    property bool reversed: false
    property var reel: null
    FloatingWindow {
        id: window
        implicitWidth: 1920; implicitHeight: 1080
        visible: true
        Wallpaper.WallpaperBrowser {
            id: browser
            width: 1920; height: 1080
            refreshOnShow: false
        }
    }
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/../wayland_keyboard.py"]
        stdinEnabled: true
        running: true
        stdout: SplitParser { onRead: line => { if (line === "released") root.released = true } }
    }
    Connections {
        target: WallpaperLibrary
        function onSelectedPathChanged() { if (root.phase === 2) ++root.selections }
    }
    function check(ok, message) {
        if (ok) return
        console.error("Wallpaper held navigation failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item) {
        if (item.objectName === "wallpaperReel") return item
        for (var child of item.children || []) {
            var found = find(child)
            if (found) return found
        }
        return null
    }
    FrameAnimation {
        running: root.phase === 2
        onTriggered: {
            var delta = (reel.offset - previousOffset + reel.count * 1.5) % reel.count - reel.count / 2
            travel -= delta * direction
            if (delta * direction > 0.001) reversed = true
            previousOffset = reel.offset
        }
    }
    Timer {
        interval: 40; repeat: true; running: true
        onTriggered: {
            root.check(++ticks < 600, "timeout")
            if (phase === 0) {
                if (!WallpaperSettingsStore.ready) return
                WallpaperLibrary.items = Array.from({length: 10}, (_, i) => ({path: "wallpaper" + i,
                    kind: i < 5 ? "static" : "video", label: "Wallpaper " + i, thumbnail: ""}))
                WallpaperLibrary.initialized = true
                WallpaperLibrary.filter = "static"
                reel = find(browser)
                phase = 1
            } else if (phase === 1) {
                if (++settle < 10) return
                reel.forceActiveFocus()
                previousOffset = reel.offset
                travel = 0; selections = 0; reversed = false; released = false; settle = 0
                phase = 2
                keyboard.write("hold " + (direction > 0 ? 106 : 105) + " 1600\n")
            } else if (phase === 2) {
                if (!released || ++settle < 8) return
                root.check(selections >= 10, "native held key repeats in " + browser.presentation)
                root.check(!reversed && travel >= selections - 1.2,
                    "artwork follows every repeated step without reversing: " + JSON.stringify({mode: browser.presentation,
                        direction: direction, selections: selections, travel: travel, reversed: reversed}))
                root.check(reel.currentIndex === WallpaperLibrary.selectedIndex && !!reel.currentItem
                    && Math.abs(reel.currentItem.x + reel.currentItem.width / 2 - reel.width / 2) < 1,
                    "release settles on the latest selected wallpaper")
                console.info("Held navigation " + browser.presentation + ": " + selections + " steps, " + travel.toFixed(2) + " items travelled")
                if (direction > 0) direction = -1
                else if (browser.presentation === "quick") {
                    browser.presentation = "workspace"
                    browser.filter = "video"
                    direction = 1
                } else {
                    console.info("Wallpaper held navigation checks passed")
                    Qt.quit()
                    return
                }
                settle = 0; phase = 1
            }
        }
    }
}
