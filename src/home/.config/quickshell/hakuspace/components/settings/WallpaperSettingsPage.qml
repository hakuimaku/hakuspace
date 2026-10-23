import QtQuick
import QtQuick.Controls
import "../../services"

Item {
    id: root
    property Item shortcutTarget: null
    signal reloadRequested()
    signal confirmationRequested(string action)
    // The shared store owns draft, Apply and Discard across browser/settings navigation.
    readonly property bool editable: WallpaperSettingsStore.ready && !WallpaperSettingsStore.loading && !WallpaperSettingsStore.saving
    readonly property var sectionCards: [playback, cache, browser]
    readonly property var sidebarSections: sectionCards.map(card => card.title)
    readonly property string activeSection: {
        var name = sidebarSections[0]
        for (var card of sectionCards) if (card.y <= scroll.contentY + 24) name = card.title
        return name
    }
    readonly property var actionLabels: ["Reload", "Reset", "Discard", "Apply"]
    readonly property var actionHints: ({Reload: "Read saved wallpaper preferences.", Reset: "Draft the recommended defaults.",
        Discard: "Restore the saved wallpaper preferences.", Apply: "Save preferences and update native playback."})
    readonly property string footerStatus: WallpaperSettingsStore.error || WallpaperSettingsStore.statusMessage
        || (WallpaperSettingsStore.loading ? "Loading…" : WallpaperSettingsStore.saving ? "Saving…" : WallpaperSettingsStore.dirty ? "Unsaved wallpaper changes" : "All wallpaper changes saved")
    readonly property bool footerDirty: WallpaperSettingsStore.dirty
    readonly property bool footerError: !!WallpaperSettingsStore.error
    // Resolve existing sidebar requests against the three wallpaper section anchors.
    function scrollToSection(name) { for (var card of sectionCards) if (card.title === name) scroll.contentY = Math.max(0, Math.min(card.y, scroll.contentHeight - scroll.height)) }
    // Keep page actions aligned with the store's asynchronous guards.
    function canActivate(label) { return label === "Reload" ? !WallpaperSettingsStore.loading && !WallpaperSettingsStore.saving
        : editable && (label === "Reset" || WallpaperSettingsStore.dirty) && (label !== "Apply" || WallpaperSettingsStore.valid) }
    // Route destructive draft replacement through the existing Settings confirmation dialog.
    function activateAction(label) {
        if (label === "Reload") reloadRequested()
        else if (label === "Reset" || label === "Discard") confirmationRequested(label.toLowerCase() + "-wallpaper")
        else WallpaperSettingsStore.apply()
    }
    // Choice rows reuse the same accessible action button as other Hikai settings.
    component Choice: Column {
        id: choice
        required property string label
        required property string section
        required property string preference
        required property var options
        width: parent.width
        spacing: 8
        Text { text: choice.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: choice.options
                delegate: SettingsActionButton {
                    required property var modelData
                    text: modelData.label
                    width: Math.max(72, Math.min(130, (choice.width - 12) / choice.options.length)); height: 34
                    selected: WallpaperSettingsStore.values[choice.section][choice.preference] === modelData.value
                    enabled: root.editable
                    focused: activeFocus
                    activeFocusOnTab: true
                    Accessible.name: choice.label + ": " + modelData.label
                    Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                    onClicked: WallpaperSettingsStore.setValue(choice.section, choice.preference, modelData.value)
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                }
            }
        }
    }
    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        Column {
            id: body
            width: scroll.width
            spacing: 24
            SettingsSectionCard {
                id: playback
                width: parent.width
                title: "Playback"
                Choice { label: "Playback profile"; section: "playback"; preference: "profile"; options: [{label: "Low Memory", value: "low-memory"}, {label: "Screen", value: "screen"}, {label: "Original", value: "original"}] }
                Text { width: parent.width; text: "Low Memory uses a 720p / 24 fps proxy when needed. Original media stays untouched. Wallpaper audio is always muted."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.pixelSize: 12 }
                Choice { label: "Hardware decoding"; section: "playback"; preference: "hardwareDecode"; options: [{label: "Auto", value: "auto"}, {label: "Prefer", value: "prefer"}, {label: "Software", value: "software"}] }
                Text { width: parent.width; text: "Decoder policy applies on the next Hikai start. Prefer uses Qt's available backend order and automatic fallback."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.pixelSize: 12 }
                Choice { label: "Pause over fullscreen windows"; section: "playback"; preference: "pauseWhenFullscreen"; options: [{label: "Off", value: false}, {label: "On", value: true}] }
                Choice { label: "Release hidden decoder"; section: "playback"; preference: "unloadWhenHidden"; options: [{label: "Off", value: false}, {label: "On", value: true}] }
                Text { text: "Release after " + WallpaperSettingsStore.values.playback.unloadDelaySec + " seconds"; color: Theme.fg; font.pixelSize: Theme.fontSize }
                SettingsSlider { width: parent.width; from: 1; to: 600; value: WallpaperSettingsStore.values.playback.unloadDelaySec; enabled: root.editable; shortcutTarget: root.shortcutTarget; Accessible.name: "Hidden decoder release delay"; onMoved: WallpaperSettingsStore.setValue("playback", "unloadDelaySec", Math.round(value)) }
                Choice { label: "Loop video"; section: "playback"; preference: "loop"; options: [{label: "Off", value: false}, {label: "On", value: true}] }
            }
            SettingsSectionCard {
                id: cache
                width: parent.width
                title: "Proxy cache"
                Choice { label: "Build proxies"; section: "proxy"; preference: "buildPolicy"; options: [{label: "On select", value: "on-select"}, {label: "Background", value: "background"}, {label: "Manual", value: "manual"}] }
                Text { text: "Cache limit · " + WallpaperSettingsStore.values.proxy.maxCacheMiB + " MiB"; color: Theme.fg; font.pixelSize: Theme.fontSize }
                SettingsSlider { width: parent.width; from: 64; to: 65536; stepSize: 64; value: WallpaperSettingsStore.values.proxy.maxCacheMiB; enabled: root.editable; shortcutTarget: root.shortcutTarget; Accessible.name: "Maximum proxy cache size"; onMoved: WallpaperSettingsStore.setValue("proxy", "maxCacheMiB", Math.round(value)) }
                Flow {
                    width: parent.width; spacing: 8
                    SettingsActionButton { text: "Clear unused"; width: 112; height: 36; enabled: !WallpaperService.busy && !WallpaperService.cacheBusy; activeFocusOnTab: true; focused: activeFocus; onClicked: WallpaperService.clearUnused(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                    SettingsActionButton { text: "Rebuild current"; width: 124; height: 36; enabled: WallpaperService.current.kind === "video" && !WallpaperService.busy; activeFocusOnTab: true; focused: activeFocus; onClicked: WallpaperService.rebuild(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                    SettingsActionButton { text: "Open cache"; width: 104; height: 36; activeFocusOnTab: true; focused: activeFocus; onClicked: WallpaperService.openCache(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                }
                Text { width: parent.width; text: WallpaperService.error || "Active and prepared proxies are protected from eviction."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.pixelSize: 12 }
            }
            SettingsSectionCard {
                id: browser
                width: parent.width
                title: "Browser"
                Choice { label: "Default filter"; section: "browser"; preference: "filter"; options: [{label: "All", value: "all"}, {label: "Images", value: "static"}, {label: "Videos", value: "video"}] }
                Choice { label: "Show source metadata"; section: "browser"; preference: "showMetadata"; options: [{label: "Off", value: false}, {label: "On", value: true}] }
            }
        }
    }
}
