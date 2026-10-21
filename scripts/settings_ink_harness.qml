import QtQuick
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
    property var longValueTooltip: null
    property int infoHoverAttempts: 0
    property var hoveredInfoCard: null
    property real infoHoverScrollY: 0
    property var closeDraft: null
    property string savedConfigRevision: ""
    property var browser: null
    property var morphButton: null
    property var navigationButton: null
    property var navigationPill: null
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
    // Fail the process so assertions cannot be mistaken for optional warnings.
    function check(ok, message) {
        if (ok) return
        console.error("Ink Settings failed at phase " + phase + ": " + message)
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
        var dialog = panel.confirmation ? find(panel.contentItem, item => item.modal === true, true) : null
        var surface = dialog ? dialog.contentItem : body
        surface.grabToImage(result => {
            check(result.saveToFile(Quickshell.env("INK_ARTIFACT_DIR") + "/" + Quickshell.env("INK_SIZE") + "-" + name + ".png"), "save screenshot")
            --root.captures
        })
        if (dialog) {
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
                var valueText = root.find(root.page, item => item.text === InfoStore.repo.path && item.elide === Text.ElideMiddle)
                root.check(valueText && valueText.implicitWidth > valueText.width, "long Info value elides")
                root.longValueTooltip = valueText.data.find(item => item.target === valueText && typeof item.open === "function")
                root.check(root.longValueTooltip, "long value keeps its tooltip")
                var infoScroll = root.find(root.page, item => item.contentY !== undefined && item.contentHeight !== undefined)
                var valuePosition = valueText.mapToItem(infoScroll, 0, valueText.height / 2)
                infoScroll.contentY = Math.max(0, Math.min(infoScroll.contentHeight - infoScroll.height,
                    infoScroll.contentY + valuePosition.y - infoScroll.height / 2))
                var point = valueText.mapToItem(root.panel.contentItem, valueText.width / 2, valueText.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
                root.capture("info-hover")
            } else if (root.phase === 19) {
                var target = root.longValueTooltip.target
                var targetPoint = target.mapToItem(root.panel.contentItem, target.width / 2, target.height / 2)
                // Redeliver motion while the compositor settles the newly positioned value.
                if (!root.longValueTooltip.active && ++root.infoHoverAttempts < 5) {
                    pointer.write(Math.round(targetPoint.x) + (root.infoHoverAttempts % 2) + " " + Math.round(targetPoint.y) + " " + root.panel.modelData.width + " " + root.panel.modelData.height + " 0\n")
                    return
                }
                root.check(root.longValueTooltip.active, "pointer reaches the elided Info value at " + targetPoint.x + "," + targetPoint.y + " on " + root.panel.modelData.name)
                root.check(root.find(root.page, item => item.title === "HakuSpace" && item.highlighted === true), "pointer hover highlights its Info block")
                if (!root.longValueTooltip.visible) return
                if (root.captureOnce("info-block-hover")) return
                root.check(root.longValueTooltip.text === InfoStore.repo.path, "hover reveals the full Info value")
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
                hideButton.forceActiveFocus()
                keyboard.write("key 57\n")
            } else if (root.phase === 30) {
                root.check(!ShellSettingsStore.dockShowTrash, "Space activates the live toggle")
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
                if (root.hoveredInfoCard.x === 0) root.page.scrollToSection("User & Session")
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
                root.check(root.hoveredInfoCard.highlighted && root.page.activeSection === "User & Session", "hovering the right Info block selects its sidebar entry")
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
                UiState.closeSettings()
                console.info("Ink Settings checks passed: " + Quickshell.env("INK_SIZE"))
                Qt.quit()
            }
            ++root.phase
        }
    }
}
