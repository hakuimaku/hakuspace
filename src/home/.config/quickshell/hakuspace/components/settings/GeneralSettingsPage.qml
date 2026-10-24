import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion

Item {
    id: root
    // Stores retain drafts when this category view is unloaded.
    property Item shortcutTarget: null
    property string category: "General"
    property bool showTitle: true
    property string highlightedId: ""
    signal reloadRequested()
    readonly property var sidebarSections: [category]
    readonly property string activeSection: category
    readonly property var actionLabels: ["Reload", "Apply"]
    readonly property var actionHints: ({Reload: "Read saved preferences.", Apply: "Save your preferences."})
    readonly property string footerStatus: SettingsStore.error || SettingsStore.statusMessage
        || (SettingsStore.loading ? "Loading…" : SettingsStore.saving ? "Saving…" : SettingsStore.dirty ? "Unsaved changes" : "All preferences saved")
    readonly property bool footerDirty: SettingsStore.dirty
    readonly property bool footerError: !!SettingsStore.error

    // Keep category actions on the existing persistence and validation path.
    function canActivate(label) { return label === "Reload" ? !SettingsStore.loading && !SettingsStore.saving : SettingsStore.ready && SettingsStore.dirty && SettingsStore.valid && !SettingsStore.saving && !SettingsStore.loading }
    function activateAction(label) { if (label === "Reload") reloadRequested(); else SettingsStore.apply() }
    // Reveal matching rows without filtering away the category context.
    function reveal(id) {
        var row = form.reveal(id)
        if (row) scroll.contentY = Math.max(0, Math.min(row.y, scroll.contentHeight - scroll.height))
    }
    function scrollToSection(name) { scroll.contentY = 0 }
    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: Motion.HScrollBar {}
        Column {
            id: content
            width: scroll.width
            spacing: Theme.sectionGap
            Text { visible: root.showTitle; text: root.category; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 5; font.weight: Font.DemiBold }
            GeneralSettingsForm { id: form; width: parent.width; category: root.category; shortcutTarget: root.shortcutTarget; highlightedId: root.highlightedId }
        }
    }
}
