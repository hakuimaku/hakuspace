import QtQuick
import Quickshell.Io
import "../../services"

QtObject {
    id: root
    // Share the same bounded hover probe across workspace presentations.
    property var selected: null
    property string profile: "screen"
    property bool active: false
    onActiveChanged: if (active) request()
    // Probe only the hovered source; the backend reuses fingerprinted metadata.
    readonly property string tooltipSourceKey: selected ? selected.path + ":" + (selected.previewVersion || "") : ""
    property string inspectedKey: ""
    property var inspectedMetadata: ({})
    readonly property var selectedMetadata: selected && selected.metadata ? selected.metadata
        : tooltipSourceKey === inspectedKey ? inspectedMetadata : ({})
    readonly property string tooltip: {
        if (!selected) return ""
        var metadata = selectedMetadata
        var lines = [selected.kind === "video" ? "Lively Wallpaper" : "Image Wallpaper"]
        if (metadata.width > 0 && metadata.height > 0)
            lines.push("Original: " + metadata.width + " × " + metadata.height + (selected.kind === "video" && metadata.fps > 0 ? " · " + Number(metadata.fps.toFixed(2)) + " FPS" : ""))
        var bytes = metadata.fileSize || selected.fileSize
        if (bytes > 0) {
            var unit = bytes >= 1073741824 ? "GiB" : bytes >= 1048576 ? "MiB" : bytes >= 1024 ? "KiB" : "B"
            var divisor = unit === "GiB" ? 1073741824 : unit === "MiB" ? 1048576 : unit === "KiB" ? 1024 : 1
            lines.push("Size: " + Number((bytes / divisor).toFixed(2)) + " " + unit)
        }
        if (metadata.codec) lines.push("Format: " + metadata.codec.toUpperCase())
        if (metadata.durationMs > 0 && selected.kind === "video") {
            var seconds = Math.round(metadata.durationMs / 1000)
            lines.push("Duration: " + Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0"))
        }
        if (selected.kind === "video") lines.push("Playback quality: " + (profile === "low-memory" ? "720p / 24 FPS" : profile === "screen" ? "Screen" : "Original"))
        if (!metadata.width) lines.push(tooltipSourceKey === inspectedKey && !metadataProbe.running ? "Metadata unavailable" : "Reading metadata…")
        return lines.join("\n")
    }
    onTooltipSourceKeyChanged: request()

    // Keep a late result associated with its source while coalescing hover changes.
    function request() {
        if (!active || !selected || selected.metadata || inspectedKey === tooltipSourceKey || metadataProbe.running) return
        inspectedKey = tooltipSourceKey
        inspectedMetadata = ({})
        metadataProbe.command = WallpaperService.command(["inspect", selected.path])
        metadataProbe.running = true
    }
    property Process metadataProbe: Process {
        stdout: StdioCollector { id: metadataOutput }
        onExited: code => {
            try { root.inspectedMetadata = code === 0 ? JSON.parse(metadataOutput.text) : ({}) }
            catch (error) { root.inspectedMetadata = ({}) }
            metadataFollowup.restart()
        }
    }
    property Timer metadataFollowup: Timer { id: metadataFollowup; interval: 0; onTriggered: root.request() }
}
