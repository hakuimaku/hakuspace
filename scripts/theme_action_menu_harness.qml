import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    // Drive the real panel while keeping mutations inside the runner's private home.
    property int phase: 0
    property int ticks: 0
    property bool capturing: false
    property string captureName: ""
    property var captureAction: null
    property string chosenFont: ""
    property int consumerIndex: 0
    readonly property var consumers: ["record", "power", "exit", "clipboard", "shortcut", "niriAnimation"]
    readonly property var surface: find(panel.contentItem, item => item.navStack !== undefined)
    readonly property var page: surface && surface.navStack.length ? surface.navStack[surface.navStack.length - 1].pageItem : null
    ActionMenuPanel { id: panel; modelData: Quickshell.screens[0] }
    Process { id: keyboard; command: ["python3", Quickshell.env("THEME_TEST_ROOT") + "/wayland_keyboard_fixture.py"]; stdinEnabled: true; running: true }

    // Fail with a phase number so assertions remain visible in captured logs.
    function check(ok, message) {
        if (ok) return
        console.error("Theme Action Menu failed at " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        for (var child of item.children || []) {
            var result = find(child, predicate)
            if (result) return result
        }
        return null
    }
    // Capture the panel surface without recording other desktop content.
    function capture(name, action) {
        capturing = true
        captureName = name
        captureAction = action
        captureDelay.restart()
    }
    function openTheme() { UiState.openActionMenu(panel.modelData.name, "theme") }

    // Record settled controls after the selection pill finishes moving.
    Timer {
        id: captureDelay
        interval: HAnimation.spatial + 50
        onTriggered: root.surface.grabToImage(result => {
            root.check(result.saveToFile(Quickshell.env("THEME_ARTIFACT_DIR") + "/" + root.captureName + ".png"), "save frame")
            var action = root.captureAction
            root.captureAction = null
            root.capturing = false
            if (action) action()
        })
    }

    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 350, "runtime timeout")
            if (root.capturing || ShellSettingsStore.loading) return
            if (root.phase !== 0 && panel.panelOpen && root.surface.phase !== "ready") return
            var page = root.page
            if (root.phase === 0) {
                WM.backendName = "hyprland"
                root.openTheme()
            } else if (root.phase === 1) {
                root.check(page && page.items.length === 3, "Hikai offers font, size and accent only")
                root.check(page.items.every(item => item.id !== "rofi" && item.id !== "waybar"), "no Classic theme entries")
                var button = root.find(page, item => item.label === "Font family")
                var label = root.find(button, item => item.text === "Font family" && item.font !== undefined)
                root.check(button && label && label.font.pixelSize === Theme.fontSize && button.radius === Theme.radius, "shared typography and radius")
                root.check(button.targetBackground.a === 0, "shared pill owns selection background")
                root.capture("theme", function() { keyboard.write("key 28\n") })
            } else if (root.phase === 2) {
                if (!page || page.title !== "Change Font" || page.loading) return
                root.check(page.filteredFonts.length > 1, "fonts load through the theme controller")
                var search = root.find(page, item => item.Accessible && item.Accessible.name === "Search fonts")
                root.check(search && search.font.pixelSize === Theme.fontSize - 1, "font search uses shell text sizing")
                search.text = "no-such-font-fixture"
                root.check(page.filteredFonts.length === 0, "font search can be empty")
                search.text = ""
                page.forceActiveFocus()
                keyboard.write("key 108\n")
            } else if (root.phase === 3) {
                if (page.selectedIndex !== 1) return
                root.chosenFont = page.filteredFonts[1]
                root.capture("theme-font", function() { keyboard.write("key 28\n") })
            } else if (root.phase === 4) {
                if (panel.panelOpen || Theme.fontFamily !== root.chosenFont) return
                root.openTheme()
            } else if (root.phase === 5) {
                page.activateIndex(1)
            } else if (root.phase === 6) {
                root.check(page.title === "Change Font Size" && root.surface.canGoBack, "size submenu opens")
                root.capture("theme-size", function() { keyboard.write("key 1\n") })
            } else if (root.phase === 7) {
                if (root.surface.canGoBack) return
                root.check(page.items.length === 3, "Escape returns to theme categories")
                page.activateIndex(1)
            } else if (root.phase === 8) {
                var size = root.find(page, item => item.label === "16 px")
                root.check(size, "readable font size labels")
                size.clicked()
            } else if (root.phase === 9) {
                if (panel.panelOpen || Theme.fontSize !== 16) return
                root.openTheme()
            } else if (root.phase === 10) {
                page.activateIndex(2)
            } else if (root.phase === 11) {
                root.check(page.title === "Change Accent Color", "accent submenu opens")
                var hex = root.find(page, item => item.Accessible && item.Accessible.name === "Custom accent color")
                root.check(hex && hex.clip && hex.font.pixelSize === Theme.fontSize - 1, "custom accent input keeps shell styling and clips text")
                root.capture("theme-accent", function() { hex.text = "#7288AE"; hex.accepted() })
            } else if (root.phase === 12) {
                if (panel.panelOpen || Theme.accent.toLowerCase() !== "#7288ae") return
                WM.backendName = "niri"
                root.openTheme()
            } else if (root.phase === 13) {
                root.check(page.items.length === 4 && page.items[3].id === "niriAnimation", "Niri option is contextual")
                root.capture("theme-niri", function() {
                    page.selectedIndex = 3
                    WM.backendName = "hyprland"
                    root.check(page.items.length === 3 && page.selectedIndex === 2, "context changes keep selection in range")
                    WM.backendName = "niri"
                    UiState.closeActionMenu()
                })
            } else if (root.phase === 14) {
                if (panel.panelOpen) return
                // Smoke shared page/surface consumers without executing their actions.
                UiState.openActionMenu(panel.modelData.name, root.consumers[root.consumerIndex])
            } else if (root.phase === 15) {
                if (!page || page.loading) return
                root.check(page.width > 0 && page.height > 0, "shared consumer has content bounds")
                root.check(page.width <= root.surface.width && page.height <= root.surface.height, "shared consumer fits its surface")
                root.capture("consumer-" + root.consumers[root.consumerIndex], function() { UiState.closeActionMenu() })
            } else if (root.phase === 16) {
                if (panel.panelOpen) return
                if (++root.consumerIndex < root.consumers.length) { root.phase = 14; return }
                console.log("Theme Action Menu checks passed")
                Qt.quit()
            }
            ++root.phase
        }
    }
}
