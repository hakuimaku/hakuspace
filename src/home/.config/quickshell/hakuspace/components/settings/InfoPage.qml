import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion

Item {
    id: root
    readonly property var device: InfoStore.hardware.device || ({})
    readonly property var cpu: InfoStore.hardware.cpu || ({})
    readonly property var memory: InfoStore.hardware.memory || ({})
    function wmName() {
        if (String(InfoStore.system.desktop || "").toLowerCase().indexOf("labwc") >= 0) return "Labwc"
        var names = { hyprland: "Hyprland", niri: "Niri", mango: "MangoWM", ext: "Wayland" }
        if (names[WM.backendName]) return names[WM.backendName]
        return "Unknown"
    }
    function sessionName() {
        var session = String(InfoStore.system.sessionType || "").toLowerCase()
        return session === "wayland" ? "Wayland" : session === "x11" ? "X11" : session || "Unknown"
    }
    function rows(items) { return items.filter(function(item) { return item.value !== undefined && item.value !== null && String(item.value).length > 0 }) }
    function bytes(value) {
        if (!Number.isFinite(value) || value <= 0) return ""
        var unit = value >= Math.pow(1024, 4) ? "TiB" : value >= Math.pow(1024, 3) ? "GiB" : "MiB"
        var divisor = unit === "TiB" ? Math.pow(1024, 4) : unit === "GiB" ? Math.pow(1024, 3) : Math.pow(1024, 2)
        return (value / divisor).toFixed(1) + " " + unit
    }
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
    function storageRows() {
        return (InfoStore.hardware.storage || []).map(function(disk) {
            var type = disk.rotational === true ? "HDD" : disk.rotational === false ? "SSD" : ""
            return { label: disk.name, value: [disk.model, root.bytes(disk.capacityBytes), type].filter(Boolean).join(" · ") }
        })
    }
    onVisibleChanged: { if (visible) InfoStore.load() }

    Column {
        anchors.fill: parent
        spacing: Theme.pad
        Row {
            width: parent.width
            height: 34
            Text {
                width: Math.max(80, parent.width - 112)
                anchors.verticalCenter: parent.verticalCenter
                text: "Info"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(Theme.fontSize * 1.18)
                font.weight: Font.DemiBold
            }
            SettingsActionButton {
                id: refreshButton
                width: 104; height: 32; radius: Theme.radius
                text: InfoStore.loading ? "Loading…" : "Refresh"
                idleColor: Theme.hoverMuted
                hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                selectedColor: Theme.hoverMuted
                foregroundColor: Theme.fg
                hoverForegroundColor: Theme.fg
                enabled: !InfoStore.loading
                activeFocusOnTab: enabled
                focused: activeFocus
                onClicked: InfoStore.refresh()
                Keys.onReturnPressed: InfoStore.refresh()
                Keys.onSpacePressed: InfoStore.refresh()
                SettingsTooltip {
                    target: refreshButton
                    active: refreshButton.hovered || refreshButton.activeFocus
                    text: "Read local repository and system information again."
                }
            }
        }
        Text {
            visible: InfoStore.error.length > 0
            text: InfoStore.error
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Flickable {
            id: scroll
            width: parent.width
            height: Math.max(0, parent.height - 48 - (InfoStore.error ? 28 : 0))
            contentWidth: width
            contentHeight: sections.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar {}
            Column {
                id: sections
                width: Math.min(scroll.width - 14, 810)
                spacing: Theme.pad * 2
                Repeater {
                    model: [
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
                    ]
                    delegate: Column {
                        id: section
                        required property var modelData
                        visible: modelData.rows.length > 0
                        width: sections.width
                        spacing: 7
                        Text {
                            text: section.modelData.title
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 1
                            font.weight: Font.DemiBold
                        }
                        Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.55 }
                        Repeater {
                            model: section.modelData.rows
                            delegate: Row {
                                id: field
                                required property var modelData
                                width: section.width
                                height: Math.max(25, valueText.implicitHeight + 4)
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
