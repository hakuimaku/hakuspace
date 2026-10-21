import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion

Item {
    id: root
    readonly property var device: InfoStore.hardware.device || ({})
    readonly property var cpu: InfoStore.hardware.cpu || ({})
    readonly property var memory: InfoStore.hardware.memory || ({})
    // Name the active compositor using the existing runtime detection.
    function wmName() {
        if (String(InfoStore.system.desktop || "").toLowerCase().indexOf("labwc") >= 0) return "Labwc"
        var names = { hyprland: "Hyprland", niri: "Niri", mango: "MangoWM", ext: "Wayland" }
        if (names[WM.backendName]) return names[WM.backendName]
        return "Unknown"
    }
    // Normalize the session protocol for display.
    function sessionName() {
        var session = String(InfoStore.system.sessionType || "").toLowerCase()
        return session === "wayland" ? "Wayland" : session === "x11" ? "X11" : session || "Unknown"
    }
    // Omit unavailable values from the local snapshot.
    function rows(items) { return items.filter(function(item) { return item.value !== undefined && item.value !== null && String(item.value).length > 0 }) }
    // Format available capacities using binary units.
    function bytes(value) {
        if (!Number.isFinite(value) || value <= 0) return ""
        var unit = value >= Math.pow(1024, 4) ? "TiB" : value >= Math.pow(1024, 3) ? "GiB" : "MiB"
        var divisor = unit === "TiB" ? Math.pow(1024, 4) : unit === "GiB" ? Math.pow(1024, 3) : Math.pow(1024, 2)
        return (value / divisor).toFixed(1) + " " + unit
    }
    // Flatten detected GPUs into labeled information rows.
    function gpuRows() {
        var result = []
        var gpus = InfoStore.hardware.gpus || []
        gpus.forEach(function(gpu, index) {
            result = result.concat(root.rows([
                { label: "GPU " + (index + 1), value: gpu.name },
                { label: "Vendor", value: gpu.vendor },
                { label: "Driver", value: gpu.driver },
                { label: "VRAM", value: root.bytes(gpu.vramBytes) }
            ]))
        })
        return result
    }
    // Describe each detected storage device.
    function storageRows() {
        return (InfoStore.hardware.storage || []).map(function(disk) {
            var type = disk.rotational === true ? "HDD" : disk.rotational === false ? "SSD" : ""
            return { label: disk.name, value: [disk.model, root.bytes(disk.capacityBytes), type].filter(Boolean).join(" · ") }
        })
    }
    onVisibleChanged: { if (visible) InfoStore.load() }

    // Hide unavailable groups in both cards and contextual navigation.
    readonly property var infoSections: [
        { title: "HakuSpace", rows: root.rows([
            { label: "Version", value: InfoStore.repo.version || "Not detected" },
            { label: "Tag", value: InfoStore.repo.exactTag },
            { label: "Branch", value: InfoStore.repo.branch },
            { label: "Commit", value: InfoStore.repo.commit },
            { label: "Commit date", value: InfoStore.repo.commitDate },
            { label: "Repository", value: InfoStore.repo.path },
            { label: "Git state", value: InfoStore.repo.detected ? (InfoStore.repo.dirty ? "Modified" : "Clean") : "Unavailable" }
        ]) },
        { title: "User & Session", rows: root.rows([
            { label: "User", value: UserIdentity.rawUser },
            { label: "Display name", value: UserIdentity.displayName },
            { label: "Hostname", value: InfoStore.system.hostname },
            { label: "Window manager", value: root.wmName() },
            { label: "Session", value: root.sessionName() },
            { label: "Desktop", value: InfoStore.system.desktop },
            { label: "Shell", value: InfoStore.system.shell }
        ]) },
        { title: "Linux", rows: root.rows([
            { label: "Distribution", value: InfoStore.system.distroPretty || "Unknown" },
            { label: "Distro ID", value: InfoStore.system.distroId },
            { label: "Distro version", value: InfoStore.system.distroVersion },
            { label: "Kernel", value: InfoStore.system.kernel },
            { label: "Architecture", value: InfoStore.system.arch }
        ]) },
        { title: "Hardware", rows: root.rows([
            { label: "Device", value: root.device.model },
            { label: "Manufacturer", value: root.device.manufacturer },
            { label: "Device version", value: root.device.version },
            { label: "CPU", value: root.cpu.model },
            { label: "CPU vendor", value: root.cpu.vendor },
            { label: "CPU cores", value: root.cpu.physicalCores
                  ? root.cpu.physicalCores + " physical · " + root.cpu.threads + " threads"
                  : root.cpu.threads ? root.cpu.threads + " threads" : "" },
            { label: "Max frequency", value: root.cpu.maxFrequencyHz
                  ? (root.cpu.maxFrequencyHz / 1000000000).toFixed(1) + " GHz" : "" },
            { label: "Memory", value: root.bytes(root.memory.totalBytes) }
        ]) },
        { title: "Graphics", rows: root.gpuRows() },
        { title: "Storage", rows: root.storageRows() },
        { title: "Runtime", rows: root.rows([
            { label: "Quickshell", value: InfoStore.system.quickshellVersion }
        ]) }
    ].filter(section => section.rows.length > 0)
    readonly property var sidebarSections: infoSections.map(section => section.title)
    // Keep the requested destination aligned when the responsive grid reflows.
    property string requestedSection: ""
    // Keep the last explicit or hovered selection independent of scrolling.
    property string activeSection: ""
    onInfoSectionsChanged: {
        requestedSection = ""
        if (!sidebarSections.includes(activeSection)) activeSection = ""
    }
    readonly property var actionLabels: ["Refresh"]
    readonly property string footerStatus: InfoStore.error || (InfoStore.loading ? "Loading…" : "System information · Local snapshot")
    readonly property bool footerDirty: false
    readonly property bool footerError: !!InfoStore.error

    // Move to a card in either the single-column or two-column grid.
    function scrollToSection(name) {
        for (var i = 0; i < cards.count; ++i) {
            var card = cards.itemAt(i)
            if (card && card.title === name) {
                scroll.cancelFlick()
                var cardY = card.mapToItem(scroll.contentItem, 0, 0).y
                scroll.contentY = Math.max(0, Math.min(cardY, scroll.contentHeight - scroll.height))
                root.requestedSection = name
                root.activeSection = name
                return
            }
        }
    }
    // Refresh is disabled while the current snapshot is loading.
    function canActivate(label) { return !InfoStore.loading }
    // Read a new snapshot without persistence actions.
    function activateAction(label) { InfoStore.refresh() }

    Column {
        anchors.fill: parent
        spacing: 6
        Text { text: "Info"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 5; font.weight: Font.DemiBold }
        Text { width: parent.width; text: "HakuSpace and the system behind your session."; color: Qt.hsla(0, 0, Qt.darker(Theme.fgDim, 1).hslLightness, 1); font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 1); wrapMode: Text.Wrap }
        Flickable {
            id: scroll
            width: parent.width
            height: Math.max(0, parent.height - y)
            contentWidth: width
            contentHeight: sections.implicitHeight + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onContentYChanged: root.requestedSection = ""
            ScrollBar.vertical: Motion.HScrollBar {}
            Grid {
                id: sections
                y: 12
                width: Math.max(0, scroll.width - 14)
                columns: width >= 740 ? 2 : 1
                columnSpacing: 16
                rowSpacing: 18
                onPositioningComplete: { if (root.requestedSection) root.scrollToSection(root.requestedSection) }
                Repeater {
                    id: cards
                    model: root.infoSections
                    delegate: SettingsSectionCard {
                        id: section
                        required property var modelData
                        title: modelData.title
                        highlighted: root.activeSection === title
                        // Hover selects the whole card without scrolling or intercepting clicks.
                        HoverHandler {
                            parent: section
                            onHoveredChanged: {
                                if (hovered) {
                                    root.requestedSection = ""
                                    root.activeSection = section.title
                                }
                            }
                        }
                        width: (sections.width - sections.columnSpacing * (sections.columns - 1)) / sections.columns
                        Repeater {
                            model: section.modelData.rows
                            delegate: Row {
                                id: field
                                required property var modelData
                                width: parent.width
                                height: Math.max(28, valueText.implicitHeight + 4)
                                spacing: Theme.pad
                                Text {
                                    width: Math.min(145, field.width * 0.31)
                                    text: field.modelData.label
                                    color: Theme.fgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: valueText
                                    width: Math.max(0, field.width - Math.min(145, field.width * 0.31) - Theme.pad)
                                    text: String(field.modelData.value)
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.weight: field.modelData.label === "Version" ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideMiddle
                                    HoverHandler { id: valueHover }
                                    SettingsTooltip {
                                        target: valueText
                                        active: valueHover.hovered && valueText.implicitWidth > valueText.width
                                        text: valueText.text
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
