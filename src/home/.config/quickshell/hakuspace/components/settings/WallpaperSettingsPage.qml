import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../services"
import "../wallpaper" as Wallpaper
import "../motion" as Motion

Item {
    id: root
    property Item shortcutTarget: null
    property string highlightedId: ""
    // Workspace popovers reuse a single section without folder or browser controls.
    property string sectionFilter: ""
    onSectionFilterChanged: {
        if (scroll) scroll.contentY = 0
        if (visible && (!sectionFilter || sectionFilter === "cache")) WallpaperService.refreshCache()
    }
    onVisibleChanged: if (visible && (!sectionFilter || sectionFilter === "cache")) WallpaperService.refreshCache()
    Component.onCompleted: if (visible && (!sectionFilter || sectionFilter === "cache")) WallpaperService.refreshCache()
    // Keep byte values readable for both small copies and large video libraries.
    function cacheSize(bytes) {
        if (!bytes) return "0 B"
        var unit = Math.min(3, Math.floor(Math.log(bytes) / Math.log(1024)))
        return Number((bytes / Math.pow(1024, unit)).toFixed(unit ? 2 : 0)) + " " + ["B", "KiB", "MiB", "GiB"][unit]
    }
    // Match search to an existing row or section in the full Wallpaper category.
    function reveal(id, section) {
        var row = folders.reveal(id)
        if (row) scroll.contentY = Math.max(0, Math.min(row.mapToItem(body, 0, 0).y, scroll.contentHeight - scroll.height))
        else scrollToSection(section)
    }
    signal reloadRequested()
    signal confirmationRequested(string action)
    // The shared store owns draft, Apply and Discard across browser/settings navigation.
    readonly property bool editable: WallpaperSettingsStore.ready && !WallpaperSettingsStore.loading && !WallpaperSettingsStore.saving
    readonly property var sectionCards: [playback, preparation, cache, browser].filter(card => card.visible)
    readonly property var sidebarSections: sectionCards.map(card => card.title)
    readonly property string activeSection: {
        var name = sidebarSections[0] || ""
        for (var card of sectionCards) if (card.y <= scroll.contentY + 24) name = card.title
        return name
    }
    readonly property var actionLabels: ["Reload", "Reset", "Discard", "Apply"]
    readonly property var actionHints: ({Reload: "Read saved wallpaper preferences.", Reset: "Draft the recommended defaults.",
        Discard: "Restore the saved wallpaper preferences.", Apply: "Save preferences and update native playback."})
    readonly property string footerStatus: WallpaperSettingsStore.error || SettingsStore.error || (SettingsStore.dirty ? "Unsaved preferences · Apply to save" : "") || WallpaperSettingsStore.statusMessage
        || (WallpaperSettingsStore.loading ? "Loading…" : WallpaperSettingsStore.saving ? "Saving…" : WallpaperSettingsStore.dirty ? "Unsaved wallpaper changes" : "All wallpaper changes saved")
    readonly property bool footerDirty: WallpaperSettingsStore.dirty || SettingsStore.dirty
    readonly property bool footerError: !!WallpaperSettingsStore.error || !!SettingsStore.error
    // Resolve existing sidebar requests against the three wallpaper section anchors.
    function scrollToSection(name) { for (var card of sectionCards) if (card.title === name) scroll.contentY = Math.max(0, Math.min(card.y, scroll.contentHeight - scroll.height)) }
    // Keep page actions aligned with the store's asynchronous guards.
    function canActivate(label) { return label === "Reload" ? !WallpaperSettingsStore.loading && !WallpaperSettingsStore.saving
        : editable && !SettingsStore.loading && !SettingsStore.saving && (label === "Reset" || WallpaperSettingsStore.dirty || SettingsStore.dirty) && (label !== "Apply" || (WallpaperSettingsStore.valid && SettingsStore.valid)) }
    // Route destructive draft replacement through the existing Settings confirmation dialog.
    function activateAction(label) {
        if (label === "Reload") reloadRequested()
        else if (label === "Reset" || label === "Discard") confirmationRequested(label.toLowerCase() + "-wallpaper")
        else { WallpaperSettingsStore.apply(); if (SettingsStore.dirty) SettingsStore.apply() }
    }
    // A shared selection surface stretches between choices and follows the active button shape.
    component Choice: Column {
        id: choice
        required property string label
        required property string section
        required property string preference
        required property var options
        width: parent.width
        spacing: Theme.spaceSm
        FontMetrics { id: choiceFont; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
        readonly property real slotWidth: choice.options.reduce((width, option) => Math.max(width, choiceFont.advanceWidth(option.label) + Theme.spaceLg * 2), 136)
        Text { text: choice.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
        Item {
            id: lane
            width: Math.min(choice.width, choice.options.length * choice.slotWidth + (choice.options.length - 1) * 6)
            height: Math.max(Theme.comfortableControlHeight, choiceFont.height * 2 + Theme.spaceSm * 2)
            readonly property int selectedIndex: choice.options.findIndex(option => option.value === WallpaperSettingsStore.values[choice.section][choice.preference])
            readonly property Item currentButton: buttons.itemAt(selectedIndex) || null
            Motion.SelectionPill {
                id: indicator
                objectName: "wallpaper-setting-indicator-" + choice.preference
                targetIndex: lane.selectedIndex
                slotCount: choice.options.length; slotSpacing: 6
                radius: lane.height / 2
            }
            Repeater {
                id: buttons
                model: choice.options
                delegate: SettingsActionButton {
                    id: button
                    required property var modelData
                    required property int index
                    objectName: "wallpaper-setting-" + choice.preference + "-" + modelData.value
                    x: index * (width + 6)
                    width: (lane.width - (choice.options.length - 1) * 6) / choice.options.length; height: lane.height
                    radius: height / 2
                    hoverScaleDelta: 0; hoverXScaleDelta: 0
                    pressScaleDelta: 0; pressXScaleDelta: 0
                    idleColor: "transparent"
                    selectedColor: "transparent"
                    hoverColor: "transparent"
                    pressedColor: "transparent"
                    focusColor: "transparent"
                    selectedOverridesHover: true
                    hoverForegroundColor: selected ? Theme.onAccentColor : Theme.fg
                    pressedForegroundColor: hoverForegroundColor
                    focusForegroundColor: hoverForegroundColor
                    selected: lane.selectedIndex === index
                    enabled: root.editable
                    Accessible.name: choice.label + ": " + modelData.label
                    Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                    onClicked: WallpaperSettingsStore.setValue(choice.section, choice.preference, modelData.value)
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    Text {
                        anchors { fill: parent; leftMargin: Theme.spaceLg; rightMargin: Theme.spaceLg; topMargin: Theme.spaceSm; bottomMargin: Theme.spaceSm }
                        text: button.modelData.label
                        color: button.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                }
            }
        }
    }
    // Prepare the library on demand without retaining browser thumbnails or a media model.
    Process {
        id: prepareLibrary
        command: WallpaperService.command(["list", "--json"])
        stdout: StdioCollector { id: libraryOutput }
        onExited: code => {
            if (code !== 0) { WallpaperService.error = "Your video collection could not be read."; return }
            try { WallpaperService.buildAll(JSON.parse(libraryOutput.text), WallpaperSettingsStore.savedValues.playback.profile) }
            catch (error) { WallpaperService.error = "Your video collection could not be read." }
        }
    }
    Flickable {
        id: scroll
        objectName: "wallpaper-settings-scroll"
        anchors.fill: parent
        contentWidth: width
        // Every sidebar section can align with the viewport, including the final card.
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        Column {
            id: body
            width: scroll.width
            spacing: 24
            SettingsSectionCard {
                width: parent.width
                title: "Wallpaper preferences"
                visible: root.sectionFilter === ""
                GeneralSettingsForm { id: folders; width: parent.width; category: "Wallpaper"; shortcutTarget: root.shortcutTarget; highlightedId: root.highlightedId }
            }
            SettingsSectionCard {
                id: playback
                width: parent.width
                title: "Video playback"
                visible: !root.sectionFilter || root.sectionFilter === "playback"
                highlighted: ["videoQuality", "videoDecoder", "hiddenVideo"].includes(root.highlightedId)
                Choice { label: "Video quality"; section: "playback"; preference: "profile"; options: [{label: "Save memory", value: "low-memory"}, {label: "Match screen", value: "screen"}, {label: "Original quality", value: "original"}] }
                Text { width: parent.width; text: "Save memory uses a smaller 720p / 24 fps copy when needed. Match screen fits your display (recommended). Original quality plays the source without resizing. Sound stays off."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                Choice { label: "Video decoder"; section: "playback"; preference: "hardwareDecode"; options: [{label: "Automatic", value: "auto"}, {label: "Prefer hardware", value: "prefer"}, {label: "Software", value: "software"}] }
                Text { width: parent.width; text: "Applies after restarting Hikai. Automatic is recommended. Prefer hardware tries GPU decoding first and falls back if unavailable."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                SettingsSwitch { width: parent.width; text: "Pause over fullscreen windows"; checked: WallpaperSettingsStore.values.playback.pauseWhenFullscreen; enabled: root.editable; shortcutTarget: root.shortcutTarget; onToggled: value => WallpaperSettingsStore.setValue("playback", "pauseWhenFullscreen", value) }
                Choice { label: "When wallpaper is hidden"; section: "playback"; preference: "unloadWhenHidden"; options: [{label: "Keep ready", value: false}, {label: "Free memory", value: true}] }
                Text { text: "Free after " + WallpaperSettingsStore.values.playback.unloadDelaySec + " seconds"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                SettingsSlider { width: parent.width; from: 1; to: 600; value: WallpaperSettingsStore.values.playback.unloadDelaySec; enabled: root.editable && WallpaperSettingsStore.values.playback.unloadWhenHidden; shortcutTarget: root.shortcutTarget; Accessible.name: "Free hidden video memory after seconds"; onMoved: WallpaperSettingsStore.setValue("playback", "unloadDelaySec", Math.round(value)) }
                SettingsSwitch { width: parent.width; text: "Loop video"; checked: WallpaperSettingsStore.values.playback.loop; enabled: root.editable; shortcutTarget: root.shortcutTarget; onToggled: value => WallpaperSettingsStore.setValue("playback", "loop", value) }
            }
            SettingsSectionCard {
                id: preparation
                width: parent.width
                title: "Video preparation"
                visible: !root.sectionFilter || root.sectionFilter === "playback"
                highlighted: root.highlightedId === "prepare"
                Choice { label: "Prepare videos"; section: "proxy"; preference: "buildPolicy"; options: [{label: "When selected", value: "on-select"}, {label: "In background", value: "background"}, {label: "Only when I ask", value: "manual"}] }
                Text { width: parent.width; text: "When selected is recommended. Prepared copies play at your chosen quality and leave the originals untouched."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
            }
            SettingsSectionCard {
                id: cache
                width: parent.width
                title: "Video cache"
                visible: !root.sectionFilter || root.sectionFilter === "cache"
                highlighted: root.highlightedId === "cache"
                Text {
                    objectName: "wallpaper-cache-usage"
                    width: parent.width
                    text: "Used: " + root.cacheSize(WallpaperService.cacheBytes) + " / " + WallpaperSettingsStore.values.proxy.maxCacheMiB + " MiB · " + WallpaperService.cacheEntries.length + " prepared copies"
                    wrapMode: Text.Wrap; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
                }
                Text {
                    width: parent.width
                    text: "Total on disk: " + root.cacheSize(WallpaperService.cacheTotalBytes) + " · Previews: " + root.cacheSize(WallpaperService.cachePreviewBytes)
                    wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2
                }
                Flow {
                    width: parent.width; spacing: 8
                    Wallpaper.WallpaperToolbarButton { useSettingsTooltip: true; objectName: "wallpaper-prepare-library"; caption: WallpaperService.buildingVideos ? "Preparing videos…" : "Prepare all videos"; width: implicitWidth; height: 40; idleColor: Theme.hoverMuted; enabled: !prepareLibrary.running && !WallpaperService.busy && !WallpaperService.cacheBusy; activeFocusOnTab: true; focused: activeFocus; onClicked: prepareLibrary.running = true; Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                    Wallpaper.WallpaperToolbarButton { useSettingsTooltip: true; objectName: "wallpaper-clear-unused"; caption: "Clear cache"; description: "Delete unused prepared videos. Keep the current wallpaper cache."; width: implicitWidth; height: 40; idleColor: Theme.hoverMuted; enabled: !WallpaperService.busy && !WallpaperService.cacheBusy; activeFocusOnTab: true; focused: activeFocus; onClicked: WallpaperService.clearUnused(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                    Wallpaper.WallpaperToolbarButton { useSettingsTooltip: true; caption: "Prepare current"; width: implicitWidth; height: 40; idleColor: Theme.hoverMuted; enabled: WallpaperService.current.kind === "video" && !WallpaperService.busy; activeFocusOnTab: true; focused: activeFocus; onClicked: WallpaperService.rebuild(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                    Wallpaper.WallpaperToolbarButton { useSettingsTooltip: true; caption: "Open cache"; width: implicitWidth; height: 40; idleColor: Theme.hoverMuted; activeFocusOnTab: true; focused: activeFocus; onClicked: WallpaperService.openCache(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                }
                Text { width: parent.width; text: WallpaperService.error || WallpaperService.cacheMessage || "Clear cache removes unused prepared videos. The current wallpaper stays available."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                Text {
                    visible: !WallpaperService.cacheEntries.length
                    text: WallpaperService.cacheMaintenanceActive ? "Reading cache…" : "No prepared video copies in cache."
                    width: parent.width; wrapMode: Text.Wrap; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2
                }
                // Keep long cache inventories virtualized inside the shared settings viewport.
                ListView {
                    id: cacheList
                    objectName: "wallpaper-cache-list"
                    width: parent.width
                    readonly property real rowHeight: Math.max(68, Theme.fontSize * 2 + 32)
                    height: Math.min(count, 4) * rowHeight + Math.max(0, Math.min(count, 4) - 1) * spacing
                    model: cache.visible ? WallpaperService.cacheEntries : []
                    spacing: 8; clip: true; boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        id: cacheRow
                        required property var modelData
                        width: cacheList.width; height: cacheList.rowHeight
                        radius: Theme.radius; color: Theme.hoverMuted
                        Column {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4
                            RowLayout {
                                width: parent.width
                                Text {
                                    objectName: "wallpaper-cache-entry-title"
                                    Layout.fillWidth: true
                                    text: cacheRow.modelData.label
                                    elide: Text.ElideRight; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
                                }
                                Text {
                                    objectName: "wallpaper-cache-entry-state"
                                    text: cacheRow.modelData.active ? "In use" : cacheRow.modelData.pending ? "Applying" : cacheRow.modelData.sourceChanged ? "Source changed" : cacheRow.modelData.path ? "Built" : "Unidentified"
                                    color: cacheRow.modelData.active ? Theme.accent : Theme.fgMuted
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2
                                }
                            }
                            Text {
                                objectName: "wallpaper-cache-entry-details"
                                width: parent.width
                                text: (cacheRow.modelData.profile === "low-memory" ? "720p" : cacheRow.modelData.profile === "screen" ? "Screen" : "Unknown quality")
                                    + (cacheRow.modelData.render.width ? " · " + cacheRow.modelData.render.width + " × " + cacheRow.modelData.render.height : "")
                                    + (cacheRow.modelData.render.fps > 0 ? " · " + Number(Number(cacheRow.modelData.render.fps).toFixed(2)) + " FPS" : "")
                                    + " · " + root.cacheSize(cacheRow.modelData.bytes)
                                elide: Text.ElideRight; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        HoverHandler { id: cacheHover }
                        SettingsTooltip {
                            target: cacheRow
                            text: cacheRow.modelData.path || cacheRow.modelData.proxyPath
                            active: cacheHover.hovered
                        }
                    }
                }
                Text { text: "Cache limit · " + WallpaperSettingsStore.values.proxy.maxCacheMiB + " MiB"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                SettingsSlider { width: parent.width; from: 64; to: 65536; stepSize: 64; value: WallpaperSettingsStore.values.proxy.maxCacheMiB; enabled: root.editable; shortcutTarget: root.shortcutTarget; Accessible.name: "Maximum video cache size"; onMoved: WallpaperSettingsStore.setValue("proxy", "maxCacheMiB", Math.round(value)) }
            }
            SettingsSectionCard {
                id: browser
                width: parent.width
                title: "Browser"
                visible: root.sectionFilter === ""
                Choice { label: "Default filter"; section: "browser"; preference: "filter"; options: [{label: "Images", value: "static"}, {label: "Videos", value: "video"}] }
                Choice { label: "Show source metadata"; section: "browser"; preference: "showMetadata"; options: [{label: "Off", value: false}, {label: "On", value: true}] }
            }
        }
    }
}
