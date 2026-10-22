import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    // All edits and process launches use the runner's disposable fixtures.
    property var panels: []
    property int phase: 0
    property int ticks: 0
    property int captures: 0
    property var capturedPages: []
    property string snapshot: ""
    property string firstFile: ""
    property string secondFile: ""
    property var search: null
    property bool typingSent: false
    property var originalRepo: ({})
    property int infoHoverAttempts: 0
    property var hoveredInfoCard: null
    property real infoHoverScrollY: 0
    property var closeDraft: null
    property string savedConfigRevision: ""
    property var browser: null
    property var morphButton: null
    property var navigationButton: null
    property var navigationPill: null
    // Sample both directions so a static centered popup cannot pass the guide checks.
    property bool guideOpeningSeen: false
    property bool guideClosingSeen: false
    readonly property var panel: panels[0] || null
    readonly property var footer: panel ? find(panel.contentItem, item => item.labels !== undefined && item.page !== undefined) : null
    readonly property var page: footer ? footer.page : null
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("INK_TEST_ROOT") + "/wayland_keyboard_fixture.py"]
        stdinEnabled: true
        running: true
    }
    Process {
        id: pointer
        command: ["python3", Quickshell.env("INK_TEST_ROOT") + "/wayland_pointer_fixture.py"]
        environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: root.panel ? root.panel.modelData.name : ""})
        stdinEnabled: true
        running: !!root.panel
    }
    Variants {
        model: Quickshell.screens
        SettingsPanel {
            id: instance
            Component.onCompleted: root.panels = root.panels.concat([instance])
        }
    }
    // Report semantic focus identity without depending on object child indexes.
    function focusDescription() {
        if (!panel) return "no Settings panel"
        var target = panel.focusedItem
        for (var item = target; item; item = item.parent) {
            if (item.settingsNavItem === true) { target = item; break }
        }
        return "region=" + panel.focusZoneIndex() + ", target=" + (target ?
            (target.settingsNavRole || "native") + ":" + (target.Accessible.name || target.text || String(target)) : "none")
    }
    // Fail the process so assertions cannot be mistaken for optional warnings.
    function check(ok, message) {
        if (ok) return
        console.error("Ink Settings failed at phase " + phase + ": " + message + " (" + focusDescription() + ")")
        Qt.exit(1)
        throw new Error(message)
    }
    // Find production controls by their public behavior rather than child indexes.
    function find(item, predicate, includePopups) {
        if (predicate(item)) return item
        if (includePopups) for (var popup of item.data || []) {
            if (popup.modal === true && popup.visible) {
                if (predicate(popup)) return popup
                var popupMatch = find(popup.contentItem, predicate) || (popup.footer ? find(popup.footer, predicate) : null)
                if (popupMatch) return popupMatch
            }
        }
        for (var child of item.children || []) {
            var found = find(child, predicate, includePopups)
            if (found) return found
        }
        return null
    }
    // Wait until the shared accent reaches the selected row after layout changes.
    function sidebarSettled() {
        var sidebar = find(panel.contentItem, item => item.sectionNames !== undefined && item.configBrowser !== undefined)
        if (sidebar.compact) return true
        if (!page.activeSection) {
            var inactivePill = find(sidebar, item => item.targetItem && typeof item.targetItem.modelData === "string" && item.currentStartY !== undefined)
            check(!inactivePill || !inactivePill.targetItem.selected, "no sidebar selection without an active section")
            return !inactivePill || inactivePill.opacity < 0.001
        }
        var pill = find(sidebar, item => item.targetItem && item.targetItem.modelData === page.activeSection && item.currentStartY !== undefined)
        check(pill && pill.shown && pill.targetItem.selected, "sidebar keeps an active selection after model changes")
        var target = pill.coordinateSpace.mapFromItem(pill.targetItem, 0, 0)
        if (Math.abs(pill.y - target.y) > 0.1 || Math.abs(pill.height - pill.targetItem.height) > 0.1) return false
        check(Qt.colorEqual(pill.color, Theme.accent), "sidebar selection has an accent fill")
        return Qt.colorEqual(pill.targetItem.foreground, "#000000")
    }
    // Both Config browser styles must align their accent with the selected file.
    function fileSelectionSettled() {
        if (browser.compact) return true
        var pill = find(browser, item => item.targetItem && item.shown && item.currentStartY !== undefined)
        check(pill && pill.targetItem.selected, "Config keeps an accent for the selected file")
        var tabs = find(browser, item => item.labels && item.labels.join("|") === "Tree|Buttons")
        var style = find(tabs, item => item.currentStartX !== undefined)
        if (Math.abs(style.currentStartX - style.targetX) > 0.1 || Math.abs(style.currentEndX - style.targetX - style.targetWidth) > 0.1
            || pill.opacity < 0.999 || find(browser, item => item.targetItem && item.shown === false && item.opacity > 0.001)) return false
        var target = pill.coordinateSpace.mapFromItem(pill.targetItem, 0, 0)
        if (Math.abs(pill.y - target.y) > 0.1 || Math.abs(pill.width - pill.targetItem.width) > 0.1) return false
        check(Qt.colorEqual(pill.color, Theme.accent), "Config selection has an accent fill")
        return Qt.colorEqual(pill.targetItem.foreground, "#000000")
    }
    // Count every real catalog row, including rows hidden by the local search.
    function countRows(item) {
        var count = item.currentValue !== undefined && item.modelData && item.modelData.key ? 1 : 0
        for (var child of item.children || []) count += countRows(child)
        return count
    }
    // Activate the real shared footer, exercising its action delegation and guards.
    function action(label) {
        var button = find(panel.confirmation ? panel.contentItem : footer, item => item.text === label && typeof item.clicked === "function", !!panel.confirmation)
        check(button && button.enabled && button.width > 0, "enabled footer action " + label)
        button.clicked()
    }
    // Save just the rendered Settings surface, without capturing the user's desktop.
    function capture(name) {
        var body = find(panel.contentItem, item => item.radius !== undefined && item.children.some(child => child.currentPage !== undefined))
        check(body, "expanded surface exists")
        var interior = body.children.find(child => child.currentPage !== undefined)
        check(interior.width > 0 && interior.height > 0 && interior.visible && interior.opacity > 0.99, "visible panel interior")
        ++captures
        var dialog = find(panel.contentItem, item => item.modal === true && item.visible, true)
        var surface = dialog ? dialog.contentItem : body
        surface.grabToImage(result => {
            check(result.saveToFile(Quickshell.env("INK_ARTIFACT_DIR") + "/" + Quickshell.env("INK_SIZE") + "-" + name + ".png"), "save screenshot")
            --root.captures
        })
        if (dialog && dialog.footer && dialog.footer.visible && dialog.footer.width > 0 && dialog.footer.height > 0) {
            ++captures
            dialog.footer.grabToImage(result => {
                check(result.saveToFile(Quickshell.env("INK_ARTIFACT_DIR") + "/" + Quickshell.env("INK_SIZE") + "-" + name + "-actions.png"), "save dialog actions screenshot")
                --root.captures
            })
        }
    }
    // Capture after the page transition and resume actions on the next event loop.
    function captureOnce(name) {
        if (capturedPages.includes(name)) return false
        if (page.parent.parent.opacity < 0.999) return true
        capturedPages = capturedPages.concat([name])
        capture(name)
        return true
    }
    // Real Escape events must bubble from focused fields to the panel confirmation flow.
    function sendEscape() { keyboard.write("key 1\n") }

    Timer {
        interval: 120
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 320, "runtime timeout")
            if (!root.panel || !ShellSettingsStore.ready || ShellSettingsStore.loading || ShellSettingsStore.saving
                || SettingsStore.loading || SettingsStore.saving || ConfigEditorStore.busy || ConfigEditorStore.openingExternal || InfoStore.loading || root.captures) return
            if (root.phase === 0) {
                Theme.apply(JSON.stringify({accent: Quickshell.env("INK_ACCENT") || "#88c0d0", font: "monospace", fgDim: "#b39ab8"}))
                UiState.openSettings(root.panel.modelData.name)
            } else if (root.phase === 1) {
                if (root.panel.expandProgress < 0.999 || !SettingsStore.ready) return
                root.check(!SettingsStore.error && !ShellSettingsStore.error, "fixtures loaded")
                root.check(root.panel.targetBodyWidth <= root.panel.modelData.width - 64 && root.panel.targetBodyHeight <= root.panel.modelData.height - 64, "32 px screen margins")
                root.check(root.panels.filter(panel => panel.panelOpen).length === 1, "single-screen ownership")
                root.check(root.countRows(root.page) === SettingsStore.catalog.length, "all catalog rows rendered")
                root.search = root.find(root.page, item => item.text !== undefined && item.border !== undefined && item.height === 38 && item.children.some(child => child.cursorPosition !== undefined))
                root.check(root.search, "keyboard-reachable search")
                root.snapshot = JSON.stringify(SettingsStore.values)
                for (var query of ["welcome message", "WELCOME_MSG", "Wallpaper", "graceful shutdown"]) {
                    root.search.text = query
                    root.check(root.page.sidebarSections.length > 0, "search by label/key/group/hint: " + query)
                }
                root.search.text = "no-such-setting-123"
                root.check(root.page.sidebarSections.length === 0 && JSON.stringify(SettingsStore.values) === root.snapshot, "empty search preserves values")
                root.search.text = ""
                root.check(root.page.sidebarSections.length === 5, "clear restores all groups")
                root.check(!root.find(root.page, item => typeof item.text === "string" && SettingsStore.catalog.some(entry => item.text === entry.key)), "setting keys are hidden")
                var description = root.find(root.page, item => item.text === SettingsStore.catalog[0].hint && item.color !== undefined)
                root.check(description && Math.abs(description.color.r - description.color.g) < 0.001
                    && Math.abs(description.color.g - description.color.b) < 0.001, "descriptions stay gray with tinted secondary text")
                var body = root.find(root.panel.contentItem, item => item.radius !== undefined && item.children.some(child => child.currentPage !== undefined))
                var interior = body.children.find(child => child.currentPage !== undefined)
                root.check(body.border.width === 0 && interior.x === (body.width < 760 || body.height < 560 ? 12 : 24), "borderless panel with responsive outer padding")
                root.page.scrollToSection("Exit")
                root.check(root.page.activeSection === "Exit", "sidebar follows section navigation")
                root.page.scrollToSection("General")
                SettingsStore.setValue("WELCOME_MSG", !SettingsStore.value("WELCOME_MSG"))
                SettingsStore.setValue("NIGHT_LIGHT_TEMPERATURE", "0")
                root.check(!SettingsStore.valid && !root.page.canActivate("Apply") && !!SettingsStore.validationMessage("NIGHT_LIGHT_TEMPERATURE"), "invalid integer rejects Apply")
                SettingsStore.discard()
                SettingsStore.setValue("WELCOME_MSG", !SettingsStore.value("WELCOME_MSG"))
                root.action("Reload")
                root.check(root.panel.confirmation === "reload", "dirty General reload prompts")
                root.action("Keep Editing")
                root.check(SettingsStore.dirty && !root.panel.confirmation, "Keep preserves draft")
                root.action("Reload")
                root.action("Discard & Reload")
            } else if (root.phase === 2) {
                if (!root.sidebarSettled()) return
                root.check(root.find(root.panel.contentItem, item => item.text === "󰮯"), "requested Settings logo")
                if (root.captureOnce("general")) return
                root.check(!SettingsStore.dirty, "General reload discards draft")
                SettingsStore.setValue("SCREENSHOT_DIR", "$HOME/Pictures/Ink")
                SettingsStore.setValue("REC_OPTS", "--test")
                SettingsStore.setValue("NIGHT_LIGHT_TEMPERATURE", "4200")
                SettingsStore.setValue("ACCENT_COLOR_MODE", "saturated")
                var listRow = root.find(root.page, item => item.currentValue !== undefined && item.modelData && item.modelData.key === "EXIT_APP_LIST_USER")
                var addInput = root.find(listRow, item => typeof item.add === "function")
                addInput.text = "ink-fixture"
                addInput.add()
                root.check(SettingsStore.value("EXIT_APP_LIST_USER")[0] === "ink-fixture", "list Add control")
                var chip = root.find(listRow, item => typeof item.removeItem === "function")
                root.check(chip, "list chip rendered")
                chip.removeItem()
                root.check(SettingsStore.value("EXIT_APP_LIST_USER").length === 0, "list Remove control")
                addInput.text = "ink-fixture"
                addInput.add()
                root.action("Apply")
            } else if (root.phase === 3) {
                root.check(!SettingsStore.error && !SettingsStore.dirty && SettingsStore.value("NIGHT_LIGHT_TEMPERATURE") === 4200, "General Apply persisted")
                root.action("Reload")
            } else if (root.phase === 4) {
                root.check(SettingsStore.value("EXIT_APP_LIST_USER")[0] === "ink-fixture", "list persisted")
                SettingsStore.setValue("EXIT_APP_LIST_USER", [])
                root.action("Apply")
                root.panel.selectedGroup = "Shell"
            } else if (root.phase === 5) {
                root.check(root.page.sidebarSections.join("|") === "Appearance|Rounded Screen|Surface|App Bar|Dockbar|Top Bar", "Shell sections")
                if (!root.sidebarSettled()) return
                var footerButtons = root.footer.labels.map(label => root.find(root.footer, item => item.text === label && typeof item.clicked === "function"))
                root.check(footerButtons.length === 4 && footerButtons.every(button => button && button.y === footerButtons[0].y
                    && button.x >= 0 && button.x + button.width <= button.parent.width + 0.1), "four Shell actions share one row inside the footer")
                if (root.captureOnce("shell")) return
                var iconSlider = root.find(root.page, item => item.from === 24 && item.to === 72)
                root.check(iconSlider && iconSlider.stepSize === 4, "icon slider starts at 24 px in steps of four")
                iconSlider.value = 24
                iconSlider.moved()
                iconSlider.value = Qt.binding(() => ShellSettingsStore.dockIconSize)
                root.check(ShellSettingsStore.dockIconSize === 24 && ShellSettingsStore.valid, "icon slider previews 24 px")
                ShellSettingsStore.setValue("dock", "iconSize", 20)
                root.check(ShellSettingsStore.dockIconSize === 24, "icon preview rejects sizes below 24 px")
                root.action("Discard")
                root.check(root.panel.confirmation === "discard-shell", "Discard requires explicit confirmation")
                root.action("Keep Editing")
                root.check(ShellSettingsStore.dockIconSize === 24, "cancel Discard preserves the draft")
                root.action("Discard")
                root.action("Discard Changes")
                root.check(ShellSettingsStore.dockIconSize === 36, "Discard restores saved icon size")
                var slider = root.find(root.page, item => item.from === 4 && item.to === 24)
                slider.value = 18
                slider.moved()
                slider.value = Qt.binding(() => ShellSettingsStore.baseRadius)
                root.check(Theme.radius === 18 && ShellSettingsStore.dirty, "actual radius slider previews")
                var themedButton = root.find(root.footer, item => item.text === "Reload" && typeof item.clicked === "function")
                root.check(themedButton.radius === 18, "Settings button follows live Theme radius")
                root.action("Discard")
                root.action("Discard Changes")
                root.check(Theme.radius === 12, "Discard restores preview")
                ShellSettingsStore.setValue("topbar", "tray", false)
                root.action("Reload")
                root.check(root.panel.confirmation === "reload-shell", "Shell reload prompts")
                root.action("Keep Editing")
                root.check(!ShellSettingsStore.showTray, "Shell Keep preserves preview")
                root.action("Reload")
                root.action("Discard & Reload")
            } else if (root.phase === 6) {
                root.check(!ShellSettingsStore.dirty && ShellSettingsStore.showTray, "Shell reload restores disk")
                ShellSettingsStore.setValue("appearance", "baseRadius", 18)
                root.action("Reset")
                root.check(root.panel.confirmation === "reset-shell" && ShellSettingsStore.baseRadius === 18, "Reset keeps the draft until confirmed")
                root.action("Keep Editing")
                root.action("Reset")
                root.action("Reset to Defaults")
                root.check(!ShellSettingsStore.dirty && ShellSettingsStore.baseRadius === 12, "Reset previews defaults")
                ShellSettingsStore.setValue("appearance", "baseRadius", 20)
                root.action("Apply")
                root.panel.selectedGroup = "Config"
            } else if (root.phase === 7) {
                if (!ConfigEditorStore.hasFile) return
                root.check(!ConfigEditorStore.error && ConfigEditorStore.files.length === 3, "same fixture file tree")
                root.firstFile = ConfigEditorStore.selectedFileId
                root.secondFile = ConfigEditorStore.files.find(file => file.id !== root.firstFile).id
                root.browser = root.find(root.panel.contentItem, item => item.buttonsView !== undefined)
                var styleTabs = root.find(root.browser, item => item.labels && item.labels.join("|") === "Tree|Buttons")
                root.check(styleTabs, "Config has Tree and Buttons tabs")
                if (!ConfigEditorStore.dirty) {
                    styleTabs.toggled(true)
                    root.check(root.browser.buttonsView && ConfigEditorStore.selectedFileId === root.firstFile && !ConfigEditorStore.dirty, "changing browser style preserves selection")
                    var stylePill = root.find(styleTabs, item => item.currentStartX !== undefined)
                    if (Math.abs(stylePill.currentStartX - stylePill.targetX) > 0.1
                        || Math.abs(stylePill.currentEndX - stylePill.targetX - stylePill.targetWidth) > 0.1) return
                    if (!root.fileSelectionSettled()) return
                    if (root.captureOnce("config-buttons")) return
                    root.snapshot = ConfigEditorStore.savedText
                    ConfigEditorStore.setText(root.snapshot + "draft\n")
                    if (root.browser.compact) {
                        var selector = root.find(root.browser, item => item.displayText !== undefined && typeof item.activated === "function")
                        selector.activated(ConfigEditorStore.files.findIndex(file => file.id === root.secondFile))
                    } else {
                        var fileButton = root.find(root.browser, item => item.modelData && item.modelData.id === root.secondFile && typeof item.clicked === "function")
                        root.check(fileButton && fileButton.text === "Niri", "button browser displays a short title")
                        fileButton.clicked()
                    }
                    root.check(root.page.confirmation === "switch", "dirty file switch prompts")
                    styleTabs.toggled(false)
                    root.check(ConfigEditorStore.dirty && ConfigEditorStore.pendingFileId === root.secondFile, "switching browser style keeps pending draft protection")
                }
                if (!root.fileSelectionSettled()) return
                if (root.captureOnce("config-confirmation")) return
                root.action("Cancel")
                root.check(ConfigEditorStore.dirty && !ConfigEditorStore.pendingFileId && ConfigEditorStore.selectedFileId === root.firstFile, "Cancel keeps draft")
                root.page.requestSelect(root.secondFile)
                root.action("Save & Switch")
            } else if (root.phase === 8) {
                if (!root.fileSelectionSettled()) return
                if (root.captureOnce("config-tree")) return
                root.check(!ConfigEditorStore.error && ConfigEditorStore.selectedFileId === root.secondFile && !ConfigEditorStore.dirty, "Save & Switch")
                root.page.requestSelect(root.firstFile)
            } else if (root.phase === 9) {
                root.check(ConfigEditorStore.text === root.snapshot + "draft\n", "switch saved exact draft")
                ConfigEditorStore.setText("unsaved replacement\n")
                root.page.requestSelect(root.secondFile)
                root.action("Discard & Switch")
            } else if (root.phase === 10) {
                root.check(ConfigEditorStore.selectedFileId === root.secondFile && !ConfigEditorStore.dirty, "Discard & Switch")
                root.snapshot = ConfigEditorStore.savedText
                ConfigEditorStore.setText("reload draft\n")
                root.action("Reload")
                root.check(root.page.confirmation === "reload", "Config dirty reload prompts")
                root.action("Keep Editing")
                root.check(ConfigEditorStore.dirty, "Keep Editing preserves draft")
                root.action("Reload")
                root.action("Discard & Reload")
            } else if (root.phase === 11) {
                root.check(!ConfigEditorStore.dirty && ConfigEditorStore.text === root.snapshot, "Config reload")
                root.page.requestOpenVsCode()
            } else if (root.phase === 12) {
                root.check(!ConfigEditorStore.error, "clean VS Code flow with stub launcher")
                ConfigEditorStore.setText(root.snapshot + "external draft\n")
                root.page.requestOpenVsCode()
                root.check(root.page.confirmation === "vscode", "VS Code dirty warning")
                root.action("Cancel")
                root.check(ConfigEditorStore.dirty && !root.page.confirmation, "VS Code cancel")
                root.page.requestOpenVsCode()
                root.action("Open Anyway")
            } else if (root.phase === 13) {
                root.check(ConfigEditorStore.dirty && !ConfigEditorStore.error, "Open Anyway keeps draft")
                if (!root.typingSent) {
                    var textInput = root.find(root.page, item => item.cursorPosition !== undefined && item.readOnly !== undefined && item.text === ConfigEditorStore.text)
                    textInput.forceActiveFocus()
                    textInput.cursorPosition = textInput.text.length
                    keyboard.write("text keyboard\n")
                    root.typingSent = true
                    return
                }
                root.check(ConfigEditorStore.text.endsWith("keyboard"), "real editor keyboard input reaches the draft")
                root.action("Save")
            } else if (root.phase === 14) {
                root.check(!ConfigEditorStore.dirty && !ConfigEditorStore.error, "Config Save")
                if (root.captureOnce("config")) return
                ConfigEditorStore.setText(ConfigEditorStore.text + "escape draft\n")
                root.action("Reload")
                var editor = root.find(root.page, item => item.cursorPosition !== undefined && item.readOnly !== undefined && item.text === ConfigEditorStore.text)
                root.check(editor, "real editor text input")
                editor.forceActiveFocus()
                root.sendEscape()
            } else if (root.phase === 15) {
                root.check(!root.page.confirmation && ConfigEditorStore.dirty && root.panel.panelOpen, "Escape cancels Config confirmation from editor")
                root.sendEscape()
            } else if (root.phase === 16) {
                root.check(root.panel.confirmation === "close", "Escape then requests close")
                root.action("Keep Editing")
                root.check(ConfigEditorStore.dirty && root.panel.panelOpen, "close Keep")
                ConfigEditorStore.discard()
                root.panel.selectedGroup = "Info"
                pointer.write("8 8 " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
            } else if (root.phase === 17) {
                if (!InfoStore.ready) return
                root.check(!InfoStore.error && root.page.sidebarSections.includes("HakuSpace"), "Info snapshot loaded")
                root.check(root.page.infoSections.every(section => section.rows.length > 0), "optional sections filtered")
                if (!root.capturedPages.includes("info")) root.page.scrollToSection("User & Session")
                if (!root.sidebarSettled()) return
                if (root.captureOnce("info")) return
                var infoSidebar = root.find(root.panel.contentItem, item => item.sectionNames !== undefined && item.configBrowser !== undefined)
                var infoScroll = root.find(root.page, item => item.contentY !== undefined && item.contentHeight !== undefined)
                var previousBottom = 0
                for (var title of root.page.sidebarSections) {
                    if (infoSidebar.compact) {
                        var sectionSelector = root.find(infoSidebar, item => item.visible && typeof item.activated === "function")
                        sectionSelector.activated(root.page.sidebarSections.indexOf(title))
                    } else {
                        var sectionButton = root.find(infoSidebar, item => item.modelData === title && typeof item.clicked === "function")
                        root.check(sectionButton, "Info sidebar button exists: " + title)
                        sectionButton.clicked()
                    }
                    root.check(root.page.activeSection === title, "Info sidebar selects its destination: " + title)
                    var infoCard = root.find(root.page, item => item.title === title && item.content !== undefined)
                    root.check(infoCard.x === 0 && Math.abs(infoCard.width - (infoScroll.width - 14)) < 1
                        && infoCard.y >= previousBottom, "Info cards occupy one full-width column: " + title)
                    previousBottom = infoCard.y + infoCard.height
                    root.check(infoCard.highlighted, "Info keeps the selected card highlighted: " + title)
                    var cardPoint = infoCard.mapToItem(infoScroll, 0, 0)
                    root.check(cardPoint.y < infoScroll.height && cardPoint.y + infoCard.height > 0, "selected Info card is visible: " + title)
                }
                infoScroll.contentY = 0
                root.check(root.page.activeSection === root.page.sidebarSections[root.page.sidebarSections.length - 1], "manual scrolling preserves the last Info selection")
                var hardware = InfoStore.hardware
                InfoStore.hardware = ({})
                root.check(!root.page.sidebarSections.includes("Graphics") && !root.page.sidebarSections.includes("Storage")
                    && !root.page.sidebarSections.includes("Hardware"), "missing optional groups leave no empty cards")
                InfoStore.hardware = hardware
                root.page.scrollToSection("HakuSpace")
                root.originalRepo = InfoStore.repo
                var longValue = "/" + "long-repository-path/".repeat(30)
                InfoStore.repo = Object.assign({}, InfoStore.repo, {path: longValue})
            } else if (root.phase === 18) {
                var valueText = root.find(root.page, item => item.text === InfoStore.repo.path && item.wrapMode === Text.Wrap)
                root.check(valueText && !valueText.truncated && valueText.implicitHeight > valueText.font.pixelSize * 2,
                    "long Info values wrap completely instead of hiding information")
                var infoScroll = root.find(root.page, item => item.contentY !== undefined && item.contentHeight !== undefined)
                infoScroll.contentY = 0
                var infoCard = root.find(root.page, item => item.title === "HakuSpace" && item.content !== undefined)
                var point = infoCard.mapToItem(root.panel.contentItem, infoCard.width / 2, 40)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
                root.capture("info-hover")
            } else if (root.phase === 19) {
                root.check(root.find(root.page, item => item.title === "HakuSpace" && item.highlighted === true), "pointer hover highlights its Info block")
                if (root.captureOnce("info-block-hover")) return
                InfoStore.repo = root.originalRepo
                root.page.scrollToSection(root.page.sidebarSections[root.page.sidebarSections.length - 1])
                root.action("Refresh")
                pointer.write("8 8 " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
            } else if (root.phase === 20) {
                root.check(root.find(root.page, item => item.title === root.page.activeSection && item.highlighted === true), "Info keeps its selected block highlighted after pointer leave and refresh")
                root.check(!InfoStore.error, "Info refresh")
                root.panel.selectedGroup = "General"
                root.search.text = ""
                var input = root.find(root.search, item => item.cursorPosition !== undefined)
                input.forceActiveFocus()
                keyboard.write("text wallpaper\n")
            } else if (root.phase === 21) {
                root.check(root.search.text === "wallpaper", "real keyboard input reaches search")
                root.check(root.page.sidebarSections.length === 1 && root.page.sidebarSections[0] === "Wallpaper", "live search visibility")
                root.sendEscape()
            } else if (root.phase === 22) {
                root.check(!root.panel.panelOpen, "Escape closes clean Settings from search")
                UiState.openSettings(root.panel.modelData.name)
            } else if (root.phase === 23) {
                if (root.panel.expandProgress < 0.999) return
                SettingsStore.setValue("WELCOME_MSG", !SettingsStore.value("WELCOME_MSG"))
                root.panel.requestClose()
                root.action("Discard & Close")
                root.check(!root.panel.panelOpen && !SettingsStore.dirty, "close Discard restores drafts")
                if (root.panels.length > 1) UiState.openSettings(root.panels[1].modelData.name)
            } else if (root.phase === 24) {
                if (root.panels.length > 1) {
                    root.check(!root.panels[0].panelOpen && root.panels[1].panelOpen, "ownership transfers to second monitor")
                    UiState.closeSettings()
                }
                UiState.openSettings(root.panel.modelData.name)
            } else if (root.phase === 25) {
                if (root.panel.expandProgress < 0.999) return
                pointer.write("8 8 " + root.panel.modelData.width + " " + root.panel.modelData.height + " 272\n")
            } else if (root.phase === 26) {
                root.check(!root.panel.panelOpen, "outside click closes Settings")
                UiState.openSettings(root.panel.modelData.name)
            } else if (root.phase === 27) {
                if (root.panel.expandProgress < 0.999) return
                keyboard.write("key 15\n")
            } else if (root.phase === 28) {
                var generalTab = root.find(root.panel.contentItem, item => item.text === "General" && typeof item.clicked === "function")
                root.check(generalTab.activeFocus, "Tab starts at the primary domains")
                keyboard.write("key 15\nkey 28\n")
            } else if (root.phase === 29) {
                root.check(root.panel.selectedGroup === "Shell", "Enter activates focused Shell tab")
                var hideButton = root.find(root.page, item => item.text === "Hide" && typeof item.clicked === "function")
                hideButton.parent.parent.forceActiveFocus()
                keyboard.write("key 28\n")
            } else if (root.phase === 30) {
                root.check(!ShellSettingsStore.dockShowTrash, "Enter activates the live toggle")
                root.action("Discard")
                root.action("Discard Changes")
                root.panel.selectedGroup = "General"
            } else if (root.phase === 31) {
                root.morphButton = root.find(root.footer, item => item.text === "Reload" && typeof item.clicked === "function")
                var buttonPoint = root.morphButton.mapToItem(root.panel.contentItem, root.morphButton.width / 2, root.morphButton.height / 2)
                pointer.write(Math.round(buttonPoint.x) + " " + Math.round(buttonPoint.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
            } else if (root.phase === 32) {
                root.check(root.morphButton.hovered && root.morphButton.radius === Theme.radius && root.morphButton.horizontalScale > 1, "real hover preserves Theme radius and morphs button width")
                if (root.captureOnce("button-hover")) return
                var buttonPoint = root.morphButton.mapToItem(root.panel.contentItem, root.morphButton.width / 2, root.morphButton.height / 2)
                pointer.write(Math.round(buttonPoint.x) + " " + Math.round(buttonPoint.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 272 1\n")
            } else if (root.phase === 33) {
                root.check(root.morphButton.pressed && root.morphButton.scale < 1, "real press contracts the morphed button")
                var buttonPoint = root.morphButton.mapToItem(root.panel.contentItem, root.morphButton.width / 2, root.morphButton.height / 2)
                pointer.write(Math.round(buttonPoint.x) + " " + Math.round(buttonPoint.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 272 0\n")
            } else if (root.phase === 34) {
                root.check(!SettingsStore.error && !root.morphButton.pressed, "morph release preserves the button action")
                root.navigationButton = root.find(root.panel.contentItem, item => item.text === "Shell" && typeof item.clicked === "function")
                root.navigationPill = root.find(root.navigationButton.parent, item => item.slotCount === 4)
                var tabPoint = root.navigationButton.mapToItem(root.panel.contentItem, root.navigationButton.width / 2, root.navigationButton.height / 2)
                pointer.write(Math.round(tabPoint.x) + " " + Math.round(tabPoint.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
            } else if (root.phase === 35) {
                if (!Qt.colorEqual(root.navigationButton.color, Theme.hoverMuted)) return
                root.check(root.navigationButton.hovered && root.panel.selectedGroup === "General", "tab hover fades gray without selecting")
                root.check(Qt.colorEqual(root.navigationPill.color, Theme.accent), "primary selection stays accent during hover")
                root.navigationButton.clicked()
                root.check(root.navigationPill.targetIndex === 1, "primary morph targets the selected tab")
            } else if (root.phase === 36) {
                if (!Qt.colorEqual(root.navigationButton.foreground, "#000000") || Math.abs(root.navigationPill.animatedStartIndex - 1) > 0.001) return
                root.check(root.navigationButton.selected && Qt.colorEqual(root.navigationButton.color, "transparent"), "selected tab keeps black text over the shared accent while hovered")
                if (!root.sidebarSettled()) return
                var sidebar = root.find(root.panel.contentItem, item => item.sectionNames !== undefined && item.configBrowser !== undefined)
                if (!sidebar.compact) {
                    root.navigationButton = root.find(sidebar, item => item.modelData === "Surface" && typeof item.clicked === "function")
                    root.navigationPill = root.find(sidebar, item => item.targetItem && item.targetItem.modelData === "Appearance" && item.currentStartY !== undefined)
                    var sectionPoint = root.navigationButton.mapToItem(root.panel.contentItem, root.navigationButton.width / 2, root.navigationButton.height / 2)
                    pointer.write(Math.round(sectionPoint.x) + " " + Math.round(sectionPoint.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
                }
            } else if (root.phase === 37) {
                if (root.navigationPill.targetItem) {
                    if (!Qt.colorEqual(root.navigationButton.color, Theme.hoverMuted)) return
                    root.check(root.navigationButton.hovered && root.page.activeSection === "Appearance", "sidebar hover fades gray without moving selection")
                    root.navigationButton.clicked()
                    root.check(root.navigationPill.targetItem === root.navigationButton, "sidebar morph follows the new section")
                }
            } else if (root.phase === 38) {
                if (!root.sidebarSettled()) return
                root.capture("navigation-accent")
            } else if (root.phase === 39) {
                root.panel.selectedGroup = "Info"
                root.page.scrollToSection("HakuSpace")
            } else if (root.phase === 40) {
                if (root.page.parent.parent.opacity < 0.999) return
                root.hoveredInfoCard = root.find(root.page, item => item.title === "User & Session" && item.content !== undefined)
                root.page.scrollToSection("User & Session")
                var infoScroll = root.find(root.page, item => item.contentY !== undefined && item.contentHeight !== undefined)
                root.infoHoverScrollY = infoScroll.contentY
                root.infoHoverAttempts = 0
                var cardPoint = root.hoveredInfoCard.mapToItem(root.panel.contentItem, root.hoveredInfoCard.width / 2, 40)
                pointer.write(Math.round(cardPoint.x) + " " + Math.round(cardPoint.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
            } else if (root.phase === 41) {
                if (!root.hoveredInfoCard.highlighted && ++root.infoHoverAttempts < 5) {
                    var cardPoint = root.hoveredInfoCard.mapToItem(root.panel.contentItem, root.hoveredInfoCard.width / 2, 40)
                    pointer.write(Math.round(cardPoint.x) + (root.infoHoverAttempts % 2) + " " + Math.round(cardPoint.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
                    return
                }
                root.check(root.hoveredInfoCard.highlighted && root.page.activeSection === "User & Session", "hovering an Info block selects its sidebar entry")
                var infoScroll = root.find(root.page, item => item.contentY !== undefined && item.contentHeight !== undefined)
                root.check(infoScroll.contentY === root.infoHoverScrollY, "Info hover selection does not scroll the content")
                if (!root.sidebarSettled()) return
                if (root.captureOnce("info-sidebar-hover")) return
                pointer.write("8 8 " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
            } else if (root.phase === 42) {
                root.check(root.page.activeSection === "User & Session" && root.hoveredInfoCard.highlighted, "leaving Info blocks retains the last hovered block and sidebar selection")
                if (!root.sidebarSettled()) return
                var infoScroll = root.find(root.page, item => item.contentY !== undefined && item.contentHeight !== undefined)
                infoScroll.contentY = Math.max(0, infoScroll.contentHeight - infoScroll.height)
            } else if (root.phase === 43) {
                root.check(root.page.activeSection === "User & Session" && root.hoveredInfoCard.highlighted, "scrolling without hover preserves the last Info selection")
                if (!root.sidebarSettled()) return
                if (root.captureOnce("info-retained-selection")) return
                root.panel.selectedGroup = "General"
                SettingsStore.setValue("WELCOME_MSG", !SettingsStore.value("WELCOME_MSG"))
                ShellSettingsStore.setValue("appearance", "baseRadius", 16)
                ConfigEditorStore.setText(ConfigEditorStore.savedText + "apply-close-fixture\n")
                root.closeDraft = {general: SettingsStore.values, shell: ShellSettingsStore.values, config: ConfigEditorStore.text}
                root.savedConfigRevision = ConfigEditorStore.savedRevision
                root.find(root.search, item => item.cursorPosition !== undefined).forceActiveFocus()
                root.sendEscape()
            } else if (root.phase === 44) {
                root.check(root.panel.confirmation === "close" && root.panel.panelOpen, "Escape opens the unsaved changes dialog")
                var dialog = root.find(root.panel.contentItem, item => item.modal === true, true)
                if (!dialog || !dialog.opened) return
                var keepButton = root.find(root.panel.contentItem, item => item.text === "Keep Editing" && typeof item.clicked === "function", true)
                root.check(keepButton && keepButton.activeFocus, "Keep Editing is the safe default focus")
                var saveClose = root.find(root.panel.contentItem, item => item.text === "Apply & Close" && typeof item.clicked === "function", true)
                root.check(saveClose && saveClose.enabled, "Apply and Close is available for valid drafts")
                SettingsStore.setValue("NIGHT_LIGHT_TEMPERATURE", "0")
                root.check(!saveClose.enabled && root.panel.closeSaveProblem.length > 0, "invalid General draft prevents Apply and Close")
                SettingsStore.setValue("NIGHT_LIGHT_TEMPERATURE", root.closeDraft.general.NIGHT_LIGHT_TEMPERATURE)
                ConfigEditorStore.conflict = true
                root.check(!saveClose.enabled, "Config conflict prevents Apply and Close")
                ConfigEditorStore.conflict = false
                if (root.captureOnce("unsaved-close")) return
                keyboard.write("key 28\n")
            } else if (root.phase === 45) {
                if (root.panel.confirmation) return
                root.check(root.panel.panelOpen && JSON.stringify(SettingsStore.values) === JSON.stringify(root.closeDraft.general)
                    && JSON.stringify(ShellSettingsStore.values) === JSON.stringify(root.closeDraft.shell)
                    && ConfigEditorStore.text === root.closeDraft.config, "Enter keeps editing without losing any draft")
                var searchInput = root.find(root.search, item => item.cursorPosition !== undefined)
                if (!searchInput.activeFocus) return
                root.sendEscape()
            } else if (root.phase === 46) {
                root.check(root.panel.confirmation === "close", "Escape reopens the close dialog after editing resumes")
                root.sendEscape()
            } else if (root.phase === 47) {
                if (root.panel.confirmation) return
                root.check(root.panel.panelOpen && SettingsStore.dirty && ShellSettingsStore.dirty && ConfigEditorStore.dirty, "Escape cancels the dialog and preserves all drafts")
                root.panel.requestClose()
            } else if (root.phase === 48) {
                // A stale hash exercises the real backend conflict response.
                ConfigEditorStore.savedRevision = "sha256:" + "0".repeat(64)
                root.action("Apply & Close")
                root.check(root.panel.applyingClose && root.panel.panelOpen, "Apply and Close waits for backend saves")
                root.panel.handleEscape()
                root.check(root.panel.confirmation === "close", "Escape cannot dismiss a pending save")
            } else if (root.phase === 49) {
                if (root.panel.applyingClose) return
                root.check(root.panel.panelOpen && root.panel.confirmation === "close" && !!root.panel.confirmationError,
                    "save failure keeps the dialog open with an error")
                root.check(!SettingsStore.dirty && !ShellSettingsStore.dirty && ConfigEditorStore.dirty
                    && ConfigEditorStore.conflict && ConfigEditorStore.text === root.closeDraft.config, "failed Config save preserves its draft after other pages save")
                if (root.captureOnce("close-save-error")) return
                ConfigEditorStore.savedRevision = root.savedConfigRevision
                ConfigEditorStore.conflict = false
                ConfigEditorStore.error = ""
                root.action("Apply & Close")
            } else if (root.phase === 50) {
                if (root.panel.applyingClose) return
                root.check(!root.panel.panelOpen && !SettingsStore.dirty && !ShellSettingsStore.dirty && !ConfigEditorStore.dirty,
                    "successful retry closes only after every draft is saved")
                UiState.openSettings(root.panel.modelData.name)
            } else if (root.phase === 51) {
                if (root.panel.expandProgress < 0.999) return
                root.check(SettingsStore.value("WELCOME_MSG") === root.closeDraft.general.WELCOME_MSG
                    && ShellSettingsStore.baseRadius === 16 && ConfigEditorStore.savedText === root.closeDraft.config,
                    "Apply and Close persists General, Shell and Config")
                root.panel.selectedGroup = "General"
                pointer.write("8 8 " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
                keyboard.write("key 15 4\n")
            } else if (root.phase === 52) {
                root.check(root.panel.selectedGroup === "Shell" && root.panel.focusZoneIndex() === 0, "Ctrl+Tab changes domains and focuses the selected tab")
                keyboard.write("key 15 5\n")
            } else if (root.phase === 53) {
                root.check(root.panel.selectedGroup === "General", "Ctrl+Shift+Tab returns to the previous domain")
                keyboard.write("key 5 8\n")
            } else if (root.phase === 54) {
                root.check(root.panel.selectedGroup === "Info", "Alt+4 opens Info")
                keyboard.write("key 64\n")
            } else if (root.phase === 55) {
                root.check(root.panel.focusZoneIndex() === 1, "F6 enters the contextual sidebar")
                var sidebar = root.find(root.panel.contentItem, item => item.sectionNames !== undefined && item.configBrowser !== undefined)
                keyboard.write(sidebar.compact ? "key 108\n" : "key 107\n")
            } else if (root.phase === 56) {
                var sidebar = root.find(root.panel.contentItem, item => item.sectionNames !== undefined && item.configBrowser !== undefined)
                if (!sidebar.compact) {
                    root.check(root.panel.focusedItem.modelData === root.page.sidebarSections[root.page.sidebarSections.length - 1], "End focuses the last sidebar section")
                    var scroll = root.find(sidebar, item => item.contentY !== undefined)
                    var position = root.panel.focusedItem.mapToItem(scroll, 0, 0)
                    root.check(position.y >= -1 && position.y + root.panel.focusedItem.height <= scroll.height + 1, "focused sidebar row is scrolled fully into view")
                    keyboard.write("key 28\n")
                }
                keyboard.write("key 64\n")
            } else if (root.phase === 57) {
                root.check(root.panel.focusZoneIndex() === 2 && root.panel.focusedItem.contentY !== undefined, "F6 enters the Info reader")
                root.snapshot = root.page.activeSection
                keyboard.write("key 102\n")
            } else if (root.phase === 58) {
                root.check(root.panel.focusedItem.contentY === 0, "Home scrolls Info to its beginning")
                keyboard.write("key 109\n")
            } else if (root.phase === 59) {
                root.check(root.panel.focusedItem.contentY > 0 && root.page.activeSection === root.snapshot, "Page Down scrolls Info without changing selection")
                InfoStore.error = "keyboard-refresh-probe"
                keyboard.write("key 63\nkey 107\n")
            } else if (root.phase === 60) {
                root.check(!InfoStore.error, "F5 refreshes the Info snapshot")
                root.check(Math.abs(root.panel.focusedItem.contentY - Math.max(0, root.panel.focusedItem.contentHeight - root.panel.focusedItem.height)) < 1, "End reaches the bottom of Info")
                keyboard.write("key 64 1\n")
            } else if (root.phase === 61) {
                root.check(root.panel.focusZoneIndex() === 1, "Shift+F6 returns to the previous region")
                keyboard.write("key 33 4\n")
            } else if (root.phase === 62) {
                root.check(root.panel.selectedGroup === "General" && root.panel.focusedItem.cursorPosition !== undefined, "Ctrl+F opens General search")
                keyboard.write("text wallpaper\n")
            } else if (root.phase === 63) {
                root.check(root.search.text === "wallpaper", "keyboard search uses the existing filter")
                keyboard.write("key 33 4\ntext exit\n")
            } else if (root.phase === 64) {
                root.check(root.search.text === "exit", "Ctrl+F selects the existing query for replacement")
                keyboard.write("key 33 4\nkey 14\nkey 3 8\n")
            } else if (root.phase === 65) {
                root.check(root.panel.selectedGroup === "Shell" && root.search.text === "", "Alt+2 changes domain without editing the cleared filter")
                ShellSettingsStore.setValue("appearance", "baseRadius", 20)
                keyboard.write("key 31 4\n")
            } else if (root.phase === 66) {
                root.check(!ShellSettingsStore.dirty && ShellSettingsStore.savedValues.appearance.baseRadius === 20, "Ctrl+S applies the current Shell page")
                ShellSettingsStore.setValue("appearance", "baseRadius", 12)
                keyboard.write("key 63\n")
            } else if (root.phase === 67) {
                root.check(root.panel.confirmation === "reload-shell" && ShellSettingsStore.dirty, "F5 protects unsaved Shell edits")
                keyboard.write("key 15 4\nkey 31 4\nkey 64\nkey 5 8\n")
            } else if (root.phase === 68) {
                root.check(root.panel.selectedGroup === "Shell" && root.panel.confirmation === "reload-shell"
                    && ShellSettingsStore.baseRadius === 12 && root.panel.focusedItem.text === "Keep Editing", "modal blocks background navigation and saving")
                root.sendEscape()
            } else if (root.phase === 69) {
                root.check(!root.panel.confirmation && ShellSettingsStore.dirty, "Escape cancels keyboard Reload without losing the draft")
                keyboard.write("key 63\n")
            } else if (root.phase === 70) {
                root.check(root.panel.focusedItem.text === "Keep Editing", "Reload confirmation retains its safe initial focus")
                keyboard.write("key 15\nkey 28\n")
            } else if (root.phase === 71) {
                root.check(!root.panel.confirmation && !ShellSettingsStore.dirty && ShellSettingsStore.baseRadius === 20, "Tab and Enter explicitly confirm Reload")
                keyboard.write("key 4 8\n")
            } else if (root.phase === 72) {
                root.check(root.panel.selectedGroup === "Config", "Alt+3 opens Config")
                root.browser.buttonsView = false
                ConfigEditorStore.setText(ConfigEditorStore.savedText + "keyboard draft\n")
                root.snapshot = ConfigEditorStore.text
                keyboard.write("key 64\n")
            } else if (root.phase === 73) {
                root.check(root.panel.focusZoneIndex() === 1, "F6 enters the Config browser")
                if (!root.browser.compact) {
                    var stops = root.panel.navItems(root.browser)
                    var nextFile = stops.findIndex(item => item.parent.modelData && item.parent.modelData.type === "file" && !item.selected)
                    root.check(nextFile >= 0, "another tree file is keyboard reachable")
                    keyboard.write("key 102\n" + "key 108\n".repeat(nextFile))
                } else keyboard.write("key 64\n")
            } else if (root.phase === 74) {
                root.check(!root.page.confirmation && ConfigEditorStore.text === root.snapshot, "moving Config focus preserves the draft")
                if (!root.browser.compact) keyboard.write("key 28\n")
            } else if (root.phase === 75) {
                if (!root.browser.compact) {
                    root.check(root.page.confirmation === "switch" && ConfigEditorStore.dirty, "Enter on another file requests protected switching")
                    keyboard.write("key 31 4\nkey 64\n")
                }
            } else if (root.phase === 76) {
                if (!root.browser.compact) {
                    root.check(root.panel.selectedGroup === "Config" && root.page.confirmation === "switch" && ConfigEditorStore.dirty
                        && root.panel.focusZoneIndex() === 3 && root.panel.focusedItem.text === "Cancel", "Config confirmation blocks implicit save; F6 reaches Cancel")
                    keyboard.write("key 28\nkey 64 1\n")
                }
            } else if (root.phase === 77) {
                root.check(root.panel.focusZoneIndex() === 2 && root.panel.focusedItem.cursorPosition !== undefined
                    && !root.page.confirmation, "Shift+F6 enters the Config editor")
                root.snapshot = ConfigEditorStore.text
                keyboard.write("key 107 4\nkey 15\n")
            } else if (root.phase === 78) {
                root.check(root.panel.focusZoneIndex() === 2 && ConfigEditorStore.text.length === root.snapshot.length + 4, "Tab still indents Config instead of leaving the editor")
                keyboard.write("key 31 4\n")
            } else if (root.phase === 79) {
                root.check(!ConfigEditorStore.dirty && !ConfigEditorStore.error, "Ctrl+S saves from inside the Config editor")
                keyboard.write("key 64\n")
            } else if (root.phase === 80) {
                root.check(root.panel.focusZoneIndex() === 3, "F6 leaves Config indentation for footer actions")
                keyboard.write("key 59\n")
            } else if (root.phase === 81) {
                var guide = root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)
                root.check(guide, "F1 starts the guide reveal")
                if (!guide.opened) {
                    if (guide.morphProgress > 0 && guide.morphProgress < 1) {
                        root.guideOpeningSeen = true
                        root.check(guide.width > guide.sourceRect.width && guide.width < guide.expandedWidth,
                            "guide grows from the question button rather than fading in at full size")
                        if (!root.capturedPages.includes("guide-morph-opening")) {
                            root.capturedPages = root.capturedPages.concat(["guide-morph-opening"])
                            root.capture("guide-morph-opening")
                        }
                    }
                    return
                }
                root.check(root.guideOpeningSeen && Math.abs(guide.x - (root.panel.modelData.width - guide.width) / 2) < 1
                    && Math.abs(guide.y - (root.panel.modelData.height - guide.height) / 2) < 1, "guide finishes centered after a visible morph")
                root.check(guide.background.radius === Theme.largeRadius && guide.sourceItem.opacity === 0,
                    "guide uses Theme radius and borrows the question button while open")
                var grid = root.find(guide.contentItem, item => item.columns !== undefined)
                root.check(grid && grid.columns === (guide.expandedWidth >= 800 ? 2 : 1), "guide groups adapt to one or two columns")
                for (var title of ["Navigation", "Actions", "Config editor", "Reading & help"]) {
                    var group = root.find(guide.contentItem, item => item.modelData && item.modelData.title === title && item.border !== undefined)
                    root.check(group && group.width > 0 && group.height > 0, "guide keeps a separate shortcut card: " + title)
                }
                var navigation = root.find(guide.contentItem, item => item.modelData && item.modelData.title === "Navigation")
                root.check(navigation.modelData.rows[0].keys[0] === "← / →"
                    && !navigation.modelData.rows.some(row => row.keys.includes("Tab")), "guide presents arrows first and keeps Tab secondary")
                var compatibility = root.find(guide.contentItem, item => item.modelData && item.modelData.title === "Reading & help")
                root.check(compatibility.modelData.rows.some(row => row.detail.startsWith("Compatibility / accessibility")),
                    "guide retains the accessibility Tab path")
                var saveKey = root.find(guide.contentItem, item => item.text === "Ctrl+S" && item.color !== undefined)
                root.check(saveKey && Qt.colorEqual(saveKey.color, Theme.accent), "guide keycaps use the Theme accent")
                var saveDescription = root.find(guide.contentItem, item => item.text === "Apply or save the current page." && item.color !== undefined)
                root.check(saveDescription && Math.abs(saveDescription.color.r - saveDescription.color.g) < 0.001
                    && Math.abs(saveDescription.color.g - saveDescription.color.b) < 0.001,
                    "guide descriptions stay neutral with tinted theme text")
                root.check(guide && root.panel.focusedItem.text === "Close guide", "F1 opens an accessible shortcut guide")
                if (root.captureOnce("keyboard-shortcuts")) return
                keyboard.write("key 15 4\nkey 5 8\nkey 107\n")
            } else if (root.phase === 82) {
                root.check(root.panel.selectedGroup === "Config" && root.panel.focusedItem.text === "Close guide", "shortcut guide blocks background navigation")
                var guide = root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)
                var guideScroll = root.find(guide.contentItem, item => item.contentY !== undefined)
                root.check(guideScroll && Math.abs(guideScroll.contentY - Math.max(0, guideScroll.contentHeight - guideScroll.height)) < 1,
                    "End reaches the last guide row without overscrolling")
                root.sendEscape()
            } else if (root.phase === 83) {
                var guide = root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)
                if (guide) {
                    if (guide.morphProgress > 0 && guide.morphProgress < 1) {
                        root.guideClosingSeen = true
                        if (!root.capturedPages.includes("guide-morph-closing")) {
                            root.capturedPages = root.capturedPages.concat(["guide-morph-closing"])
                            root.capture("guide-morph-closing")
                        }
                    }
                    return
                }
                root.check(root.guideClosingSeen, "guide visibly morphs back before releasing its modal focus")
                root.check(!root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)
                    && root.panel.focusZoneIndex() === 3, "Escape closes the guide and restores prior focus")
                keyboard.write("key 2 8\nkey 106\n")
            } else if (root.phase === 84) {
                root.check(root.panel.selectedGroup === "Shell", "Right arrow selects the next top-level tab")
                keyboard.write("key 102\n")
            } else if (root.phase === 85) {
                root.check(root.panel.selectedGroup === "General", "Home selects the first top-level tab")
                SettingsStore.setValue("NIGHT_LIGHT_TEMPERATURE", "0")
                keyboard.write("key 31 4\n")
            } else if (root.phase === 86) {
                root.check(SettingsStore.dirty && !SettingsStore.valid && !SettingsStore.saving, "Ctrl+S cannot bypass General validation")
                SettingsStore.discard()
                keyboard.write("key 4 8\n")
            } else if (root.phase === 87) {
                ConfigEditorStore.setText(ConfigEditorStore.savedText + "retained warning\n")
                root.page.requestOpenVsCode()
                root.check(root.page.confirmation === "vscode", "dirty Config warning is visible")
                keyboard.write("key 33 4\n")
            } else if (root.phase === 88) {
                root.check(root.panel.selectedGroup === "General" && ConfigEditorStore.dirty, "Ctrl+F leaves Config without losing its pending draft")
                keyboard.write("key 5 8\n")
            } else if (root.phase === 89) {
                root.check(root.panel.selectedGroup === "Info", "a hidden Config confirmation does not block other page shortcuts")
                var configPage = root.find(root.panel.contentItem, item => typeof item.cancelConfirmation === "function")
                configPage.cancelConfirmation()
                ConfigEditorStore.discard()
                keyboard.write("key 3 8\n")
            } else if (root.phase === 90) {
                ShellSettingsStore.setValue("appearance", "baseRadius", 12)
                keyboard.write("key 64 1\nkey 106\n")
            } else if (root.phase === 91) {
                root.check(root.panel.focusZoneIndex() === 3 && root.panel.focusedItem.text === "Reset"
                    && ShellSettingsStore.baseRadius === 12 && !root.panel.confirmation, "footer arrows move focus without accidentally resetting")
                keyboard.write("key 107\n")
            } else if (root.phase === 92) {
                root.check(root.panel.focusedItem.text === "Apply", "End reaches the final enabled footer action")
                var hideButton = root.find(root.page, item => item.text === "Hide" && typeof item.clicked === "function")
                hideButton.parent.parent.forceActiveFocus()
                keyboard.write("key 28\n")
            } else if (root.phase === 93) {
                root.check(!ShellSettingsStore.dockShowTrash, "Enter toggles the whole segmented control off")
                keyboard.write("key 28\n")
            } else if (root.phase === 94) {
                root.check(ShellSettingsStore.dockShowTrash, "Enter toggles the whole segmented control on")
                ShellSettingsStore.discard()
                var question = root.find(root.panel.contentItem, item => item.text === "?" && typeof item.clicked === "function")
                var questionPoint = question.mapToItem(root.panel.contentItem, question.width / 2, question.height / 2)
                pointer.write(Math.round(questionPoint.x) + " " + Math.round(questionPoint.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 272\n")
            } else if (root.phase === 95) {
                var guide = root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)
                root.check(guide && guide.morphProgress > 0 && guide.morphProgress < 1, "question-button click starts a slow morph")
                var source = guide.sourceItem.mapToItem(root.panel.contentItem, 0, 0)
                root.check(Math.abs(guide.sourceRect.x - source.x) < 2 && Math.abs(guide.sourceRect.y - source.y) < 2,
                    "morph origin follows the real question-button position")
                keyboard.write("key 59\n")
            } else if (root.phase === 96) {
                var guide = root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)
                root.check(guide && guide.morphProgress > 0 && guide.morphProgress < 1, "closing can interrupt the opening morph")
                keyboard.write("key 59\n")
            } else if (root.phase === 97) {
                var guide = root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)
                root.check(guide, "reopening reverses the closing guide")
                if (!guide.opened) return
                root.check(guide.morphProgress === 1 && root.panel.focusedItem.text === "Close guide", "interrupted guide returns to a fully interactive state")
                root.sendEscape()
            } else if (root.phase === 98) {
                if (root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)) return
                root.check(!SettingsStore.dirty && !ShellSettingsStore.dirty && !ConfigEditorStore.dirty, "guide animation never changes a settings draft")
                keyboard.write("key 3 8\n")
            } else if (root.phase === 99) {
                root.check(root.panel.focusZoneIndex() === 0, "Alt+2 focuses Shell navigation")
                root.page.scrollToSection("Appearance")
                keyboard.write("key 108\n")
            } else if (root.phase === 100) {
                root.check(root.panel.focusZoneIndex() === 1, "Down enters the sidebar directly")
                keyboard.write("key 102\nkey 103\n")
            } else if (root.phase === 101) {
                root.check(root.panel.focusZoneIndex() === 0, "Up from the first sidebar control returns to navigation")
                keyboard.write("key 108\nkey 106\n")
            } else if (root.phase === 102) {
                root.check(root.panel.focusZoneIndex() === 2 && root.panel.focusedItem.keyboardEditing === false,
                    "Right enters the selected appearance section at its slider")
                root.snapshot = String(ShellSettingsStore.baseRadius)
                keyboard.write("key 106\n")
            } else if (root.phase === 103) {
                root.check(String(ShellSettingsStore.baseRadius) === root.snapshot, "navigation arrows cannot adjust a slider")
                keyboard.write("key 28\nkey 106\n")
            } else if (root.phase === 104) {
                root.check(root.panel.focusedItem.keyboardEditing && ShellSettingsStore.baseRadius === Number(root.snapshot) + 1,
                    "Enter then Right adjusts the slider: editing=" + root.panel.focusedItem.keyboardEditing
                    + ", value=" + ShellSettingsStore.baseRadius + ", before=" + root.snapshot)
                keyboard.write("key 1\n")
            } else if (root.phase === 105) {
                root.check(root.panel.panelOpen && !root.panel.focusedItem.keyboardEditing && !root.panel.confirmation,
                    "Escape exits slider editing without closing Settings")
                keyboard.write("key 105\n")
            } else if (root.phase === 106) {
                root.check(root.panel.focusZoneIndex() === 1, "Left at the content edge returns to the sidebar")
                keyboard.write("key 106 4\nkey 28\nkey 105 4\n")
            } else if (root.phase === 107) {
                root.check(root.panel.focusZoneIndex() === 1, "Ctrl+Left leaves an editing slider for the sidebar")
                keyboard.write("key 103 4\n")
            } else if (root.phase === 108) {
                root.check(root.panel.focusZoneIndex() === 0, "Ctrl+Up focuses navigation")
                keyboard.write("key 108 4\n")
            } else if (root.phase === 109) {
                root.check(root.panel.focusZoneIndex() === 2 && !root.panel.focusedItem.keyboardEditing,
                    "Ctrl+Down restores content with slider editing finished")
                var hideButton = root.find(root.page, item => item.text === "Hide" && typeof item.clicked === "function")
                hideButton.parent.parent.forceActiveFocus()
                root.snapshot = String(ShellSettingsStore.dockShowTrash)
                keyboard.write("key 103\n")
            } else if (root.phase === 110) {
                root.check(String(ShellSettingsStore.dockShowTrash) === root.snapshot, "toggle arrows navigate without changing its value")
                ShellSettingsStore.discard()
                keyboard.write("key 33 4\n")
            } else if (root.phase === 111) {
                root.check(root.panel.focusedItem.text === "", "Ctrl+F enters the native search input")
                root.panel.focusedItem.text = "wallpaper"
                root.panel.focusedItem.cursorPosition = 2
                keyboard.write("key 105\n")
            } else if (root.phase === 112) {
                root.check(root.panel.focusZoneIndex() === 2 && root.panel.focusedItem.cursorPosition === 1,
                    "Left inside text preserves caret navigation")
                root.panel.focusedItem.cursorPosition = 0
                keyboard.write("key 105\n")
            } else if (root.phase === 113) {
                root.check(root.panel.focusZoneIndex() === 1, "Left at the text boundary focuses the sidebar")
                root.search.text = ""
                keyboard.write("key 3 8\n")
            } else if (root.phase === 114) {
                root.page.scrollToSection("Surface")
                root.find(root.page, item => item.text === "Ink" && typeof item.clicked === "function").forceActiveFocus()
                root.snapshot = ShellSettingsStore.surfaceTone
                keyboard.write("key 106\n")
            } else if (root.phase === 115) {
                root.check(root.panel.focusedItem.text === "Dark" && ShellSettingsStore.surfaceTone === root.snapshot,
                    "Right focuses the next control in the same row without activating it")
                keyboard.write("key 105\n")
            } else if (root.phase === 116) {
                root.check(root.panel.focusedItem.text === "Ink", "Left returns to the previous control before leaving content")
                keyboard.write("key 105 4\nkey 106 4\n")
            } else if (root.phase === 117) {
                root.check(root.panel.focusedItem.text === "Ink", "region navigation restores the last control in its section")
                keyboard.write("key 4 8\nkey 108 4\n")
            } else if (root.phase === 118) {
                root.check(root.panel.focusZoneIndex() === 2 && root.panel.focusedItem.cursorPosition !== undefined,
                    "Ctrl+Down enters the native Config editor")
                root.snapshot = ConfigEditorStore.text
                keyboard.write("key 105 4\n")
            } else if (root.phase === 119) {
                root.check(root.panel.focusZoneIndex() === 1 && ConfigEditorStore.text === root.snapshot,
                    "Ctrl+Left leaves the editor without editing its text")
                keyboard.write("key 106 4\n")
            } else if (root.phase === 120) {
                root.check(root.panel.focusZoneIndex() === 2 && root.panel.focusedItem.cursorPosition !== undefined
                    && ConfigEditorStore.text === root.snapshot, "Ctrl+Right returns from the Config sidebar to its editor")
                var editorTarget = root.panel.focusedItem
                root.panel.focusZone(0)
                editorTarget.activeFocusOnTab = false
                root.check(!editorTarget.activeFocusOnTab && root.panel.navItems(root.page).includes(editorTarget),
                    "arrow registry does not depend on activeFocusOnTab")
                editorTarget.activeFocusOnTab = true
                var question = root.find(root.panel.contentItem, item => item.text === "?" && typeof item.clicked === "function")
                root.check(question.activeFocusOnTab && !root.panel.navItems(root.panel.focusZones[0]).includes(question),
                    "compatibility-only help is absent from the domain arrow registry")
                var style = root.find(root.browser, item => item.labels && item.labels[0] === "Tree")
                style.available = false
                root.check(!root.panel.navItems(root.browser).includes(style), "unavailable shared toggles leave the arrow registry")
                style.available = true
                keyboard.write("key 5 8\nkey 106\n")
            } else if (root.phase === 121) {
                root.check(root.panel.selectedGroup === "General" && root.panel.focusedItem.settingsNavRole === "domain",
                    "Right wraps Info to General and skips help")
                keyboard.write("key 105\n")
            } else if (root.phase === 122) {
                root.check(root.panel.selectedGroup === "Info", "Left wraps General to Info")
                root.panel.focusZone(3)
                keyboard.write("key 103\n")
            } else if (root.phase === 123) {
                root.check(root.panel.focusZoneIndex() === 2 && root.panel.focusedItem.settingsNavRole === "reader",
                    "footer Up returns to content without invoking an action")
                keyboard.write("key 3 8\n")
            } else if (root.phase === 124) {
                root.page.scrollToSection("Appearance")
                root.panel.focusZone(1)
                root.snapshot = JSON.stringify(ShellSettingsStore.values)
                keyboard.write("key 106\nkey 103\n")
            } else if (root.phase === 125) {
                root.check(root.panel.focusZoneIndex() === 0, "Up from the first normal content row returns to the domain")
                keyboard.write("key 108\nkey 106\nkey 108\n")
            } else if (root.phase === 126) {
                root.check(root.panel.focusZoneIndex() === 2 && root.panel.focusedItem.from === 0 && root.panel.focusedItem.to === 24,
                    "Down enters the adjacent Rounded Screen row without changing a value")
                var controls = root.panel.navItems(root.page)
                controls[controls.length - 1].forceActiveFocus()
                keyboard.write("key 108\n")
            } else if (root.phase === 127) {
                root.check(root.panel.focusZoneIndex() === 3 && JSON.stringify(ShellSettingsStore.values) === root.snapshot,
                    "Down from the last normal content row enters footer without changing settings")
                keyboard.write("key 103\n")
            } else if (root.phase === 128) {
                var controls = root.panel.navItems(root.page)
                root.check(root.panel.focusedItem === controls[controls.length - 1], "footer Up restores the last form control")
                root.page.scrollToSection("Appearance")
                root.panel.focusZone(1)
                keyboard.write("key 106\n")
            } else if (root.phase === 129) {
                root.check(root.panel.focusedItem.from === 4 && root.panel.focusedItem.to === 24,
                    "entering a different section rejects stale focus from another section")
                keyboard.write("key 2 8\n")
            } else if (root.phase === 130) {
                var control = root.panel.navItems(root.page).find(item => item.settingsNavRole === "control")
                root.check(control, "General exposes semantic controls")
                control.forceActiveFocus()
                root.search.text = "no-such-setting-123"
            } else if (root.phase === 131) {
                root.check(root.panel.focusedItem.text === "no-such-setting-123" && root.panel.focusedItem.visible,
                    "filter changes recover focus from controls hidden by the query")
                root.panel.focusZone(0)
                root.check(root.panel.navigateTopbar({key: Qt.Key_Down}) && root.panel.focusZoneIndex() === 2
                    && root.panel.focusedItem.text === "no-such-setting-123", "empty contextual navigation is skipped back to search")
                root.search.text = ""
                keyboard.write("key 4 8\nkey 108 4\n")
            } else if (root.phase === 132) {
                root.panel.focusedItem.cursorPosition = 0
                root.snapshot = ConfigEditorStore.text
                keyboard.write("key 105\nkey 103\nkey 106\n")
            } else if (root.phase === 133) {
                root.check(root.panel.focusZoneIndex() === 2 && root.panel.focusedItem.cursorPosition === 1
                    && ConfigEditorStore.text === root.snapshot, "bare editor arrows keep caret ownership even at the document boundary")
                keyboard.write("key 2 8\nkey 105 4\n")
            } else if (root.phase === 134) {
                if (root.browser.compact) {
                    root.check(root.panel.focusedItem.settingsNavRole === "selector", "compact sidebar enters its native selector")
                    keyboard.write("key 57\n")
                }
            } else if (root.phase === 135) {
                if (root.browser.compact) {
                    var sidebar = root.panel.focusZones[1]
                    root.check(sidebar.popupOpen && !root.panel.navigationEnabled, "open ComboBox blocks background navigation")
                    root.snapshot = JSON.stringify(SettingsStore.values)
                    keyboard.write("key 108\nkey 106 4\n")
                }
            } else if (root.phase === 136) {
                if (root.browser.compact) {
                    root.check(root.panel.focusZones[1].popupOpen && root.panel.selectedGroup === "General"
                        && JSON.stringify(SettingsStore.values) === root.snapshot,
                        "native popup arrows and shortcuts cannot enter background content or mutate settings")
                    root.sendEscape()
                }
            } else if (root.phase === 137) {
                if (root.browser.compact) {
                    root.check(!root.panel.focusZones[1].popupOpen, "Escape closes only the native popup")
                    keyboard.write("key 106\n")
                }
            } else if (root.phase === 138) {
                if (root.browser.compact) root.check(root.panel.focusZoneIndex() === 2, "Right resumes content navigation after popup close")
                root.panel.selectedGroup = "Shell"
                root.panel.focusZone(0)
                root.navigationButton = root.panel.focusedItem
                ShellSettingsStore.setValue("appearance", "baseRadius", ShellSettingsStore.baseRadius === 12 ? 13 : 12)
                root.snapshot = JSON.stringify(ShellSettingsStore.values)
                root.panel.requestClose()
            } else if (root.phase === 139) {
                var dialog = root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)
                if (!dialog.opened) return
                root.check(root.panel.focusedItem.text === "Keep Editing", "dirty close focuses its safe dialog action")
                keyboard.write("key 106\n")
            } else if (root.phase === 140) {
                root.check(root.panel.focusedItem.text === "Discard & Close" && root.panel.selectedGroup === "Shell"
                    && root.panel.confirmation === "close" && JSON.stringify(ShellSettingsStore.values) === root.snapshot
                    && ShellSettingsStore.dirty, "dialog arrows move between actions without changing settings")
                keyboard.write("key 15 4\nkey 31 4\nkey 2 8\n")
            } else if (root.phase === 141) {
                root.check(root.panel.selectedGroup === "Shell" && root.panel.confirmation === "close"
                    && JSON.stringify(ShellSettingsStore.values) === root.snapshot && ShellSettingsStore.dirty
                    && root.panel.focusZoneIndex() === -1, "modal blocks background shortcuts and retains keyboard focus")
                keyboard.write("key 102\nkey 28\n")
            } else if (root.phase === 142) {
                if (root.find(root.panel.contentItem, item => item.modal === true && item.visible, true)) return
                root.check(root.panel.panelOpen && !root.panel.confirmation && root.panel.focusedItem === root.navigationButton,
                    "cancelled modal restores its previous valid focus")
                ShellSettingsStore.discard()
                keyboard.write("key 4 8\nkey 105 4\n")
            } else if (root.phase === 143) {
                root.snapshot = ConfigEditorStore.selectedFileId
                keyboard.write("key 108\nkey 105\n")
            } else if (root.phase === 144) {
                root.check(ConfigEditorStore.selectedFileId === root.snapshot && !root.page.confirmation,
                    "closed Config selector or file arrows move focus without switching the file")
                if (root.panels.length > 1) UiState.openSettings(root.panels[1].modelData.name)
            } else if (root.phase === 145) {
                if (root.panels.length > 1) {
                    var other = root.panels[1]
                    if (root.panel.visible || other.expandProgress < 0.999 || !other.contentItem.Window.window.active) return
                    other.focusZone(0)
                    root.snapshot = root.panel.selectedGroup
                    keyboard.write("key 106\n")
                }
            } else if (root.phase === 146) {
                if (root.panels.length > 1) {
                    root.check(root.panels[1].selectedGroup === "Shell" && root.panel.selectedGroup === root.snapshot,
                        "domain arrows affect only the open Settings instance on the second monitor")
                    UiState.closeSettings()
                }
            } else if (root.phase === 147) {
                if (root.panels.length > 1 && root.panels[1].visible) return
                if (!root.panel.panelOpen) { UiState.openSettings(root.panel.modelData.name); return }
                if (root.panel.expandProgress < 0.999 || !root.panel.contentItem.Window.window.active) return
                root.panel.focusZone(0)
                root.check(root.panel.panelOpen, "keyboard ownership returns to the original monitor")
                root.panel.selectedGroup = "General"
                root.page.scrollToSection("Exit")
                root.snapshot = JSON.stringify(SettingsStore.values)
                root.check(root.panel.navigationEnabled, "reopened Settings accepts navigation: domain=" + root.panel.selectedGroup
                    + ", modal=" + root.panel.confirmation + ", popup=" + root.panel.focusZones[1].popupOpen)
                keyboard.write("key 33 4\n")
            } else if (root.phase === 148) {
                root.check(root.panel.focusedItem.text === "", "fixed search retains focus above a scrolled form: domain="
                    + root.panel.selectedGroup + ", navigation=" + root.panel.navigationEnabled
                    + ", other=" + (root.panels.length > 1 ? root.panels[1].selectedGroup : "none"))
                keyboard.write("key 108\n")
            } else if (root.phase === 149) {
                var section = ""
                for (var item = root.panel.focusedItem; item && item !== root.page; item = item.parent) {
                    if (item.settingsNavSection !== undefined) { section = item.settingsNavSection; break }
                }
                root.check(section === root.page.sidebarSections[0] && JSON.stringify(SettingsStore.values) === root.snapshot,
                    "Down from fixed search enters the first semantic form row regardless of scroll position")
                UiState.closeSettings()
                console.info("Ink Settings checks passed: " + Quickshell.env("INK_SIZE"))
                Qt.quit()
            }
            ++root.phase
        }
    }
}
