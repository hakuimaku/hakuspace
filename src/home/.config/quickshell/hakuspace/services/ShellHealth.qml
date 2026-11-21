pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    // Monitor resident Hikai services without gating backend cutover.
    readonly property bool active: AppState.shellBackend === "hikai"
    readonly property string logPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hakuspace/hikai-health.log"
    property bool graceElapsed: false
    property int retryAttempts: 0
    readonly property int maxRetries: 3
    property string reportedSignature: ""
    property string pendingSignature: ""
    property double degradedSinceMs: 0
    property double lastCheckedAtMs: 0

    readonly property var issues: {
        if (!active) return []
        var list = []

        if (!ShellSettingsStore.ready || ShellSettingsStore.error !== "") {
            list.push({
                id: "shellSettings",
                label: "Shell Settings",
                severity: "error",
                detail: ShellSettingsStore.error || "Shell preferences failed to load (hikai-shell.json)."
            })
        }

        if (SettingsStore.error !== "") {
            list.push({
                id: "generalSettings",
                label: "General & Theme Settings",
                severity: "error",
                detail: SettingsStore.error
            })
        }

        if (IdleService.owner && !IdleService.releasing) {
            if (IdleService.error !== "") {
                list.push({
                    id: "idle",
                    label: "Idle & Power",
                    severity: "error",
                    detail: IdleService.error + ". Auto-lock, display off, and suspend may be paused."
                })
            } else if (IdleService.customInhibit && IdleService.customInhibit.error) {
                list.push({
                    id: "idle",
                    label: "Idle & Power",
                    severity: "error",
                    detail: "Inhibitor check failed (" + IdleService.customInhibit.error + "). Idle stages are paused."
                })
            } else if (!IdleService.recovered || !IdleService.logindReady ||
                (IdleService.settings && IdleService.settings.enabled && !IdleService.enabled)) {
                var idleReason = !ShellSettingsStore.ready ? "Waiting for ShellSettingsStore"
                    : !IdleService.recovered ? "Idle ownership claim/recovery pending"
                    : !IdleService.logindReady ? "Logind session watch not ready"
                    : "Idle monitors inactive"
                list.push({
                    id: "idle",
                    label: "Idle & Power",
                    severity: "error",
                    detail: idleReason + ". Auto-lock, display off, and suspend are paused."
                })
            }
        }

        if (!WM.supported && !WM.labwcSession) {
            list.push({
                id: "wm",
                label: "Window Manager IPC",
                severity: "error",
                detail: "Compositor backend unavailable (" + WM.backendName + "). Workspaces, titles, and DPMS are degraded."
            })
        }

        if (!WallpaperSettingsStore.ready || WallpaperSettingsStore.error !== "" || WallpaperService.error !== "") {
            list.push({
                id: "wallpaper",
                label: "Wallpaper",
                severity: "error",
                detail: WallpaperService.error || WallpaperSettingsStore.error || "Wallpaper settings failed to load."
            })
        }

        if (CavaService.enabled && (!CavaService.available || CavaService.errorString !== "")) {
            list.push({
                id: "cava",
                label: "Cava Visualizer",
                severity: "error",
                detail: CavaService.errorString || "Cava audio visualizer is unavailable."
            })
        }

        if (MemoryMaintenance.enabled && MemoryMaintenance.error !== "") {
            list.push({
                id: "memory",
                label: "Memory Maintenance",
                severity: "warning",
                detail: MemoryMaintenance.error
            })
        }

        return list
    }

    readonly property int issueCount: (issues || []).length
    readonly property bool hasIssues: active && issueCount > 0
    readonly property bool degraded: hasIssues && graceElapsed
    readonly property bool showIndicator: degraded
    readonly property string faultSignature: (issues || []).map(item => item.id + ":" + item.detail).join("|")

    function retryFailingServices() {
        lastCheckedAtMs = Date.now()
        for (var i = 0; i < issues.length; i++) {
            var id = issues[i].id
            if (id === "shellSettings") {
                if (!ShellSettingsStore.loading && !ShellSettingsStore.saving) ShellSettingsStore.reload()
            } else if (id === "generalSettings") {
                if (!SettingsStore.loading && !SettingsStore.saving) SettingsStore.reload()
            } else if (id === "wallpaper") {
                if (!WallpaperSettingsStore.loading && !WallpaperSettingsStore.saving) WallpaperSettingsStore.reload()
            } else if (id === "idle") {
                IdleService.retryReadiness()
            } else if (id === "cava") {
                if (CavaService.enabled) CavaService.restart()
            }
        }
    }

    function retryNow() {
        if (!active) return "error:inactive"
        retryAttempts = 0
        retryFailingServices()
        if (hasIssues && !graceElapsed && !graceTimer.running) graceTimer.restart()
        if (hasIssues && !retryTimer.running) retryTimer.restart()
        return "ok"
    }

    function formatReport() {
        var lines = [
            "HakuSpace Hikai Health Report",
            "timestamp=" + new Date().toISOString(),
            "backend=" + AppState.shellBackend,
            "wm=" + WM.backendName,
            "issueCount=" + issueCount,
            ""
        ]
        for (var i = 0; i < issues.length; i++) {
            var item = issues[i]
            lines.push("[" + item.severity.toUpperCase() + "] " + item.id + " (" + item.label + "): " + item.detail)
        }
        var hasIdle = issues.some(item => item.id === "idle")
        if (hasIdle) {
            lines.push("")
            lines.push("--- recent [idle] events ---")
            var recent = (IdleService.runtimeEvents || []).slice(-12)
            for (var j = 0; j < recent.length; j++) lines.push(JSON.stringify(recent[j]))
        }
        return lines.join("\n")
    }

    function dispatchReport() {
        if (!degraded || !faultSignature || faultSignature === reportedSignature) return
        if (reporter.running) {
            pendingSignature = faultSignature
            return
        }
        var summaryLines = issues.slice(0, 3).map(item => "• " + item.label + ": " + item.detail)
        if (issues.length > 3) summaryLines.push("• +" + (issues.length - 3) + " more issue(s)")
        summaryLines.push("Log: " + logPath)
        var sig = faultSignature
        reportedSignature = sig
        pendingSignature = ""
        reporter.environment = {
            HAKUSPACE_HEALTH_LOG: logPath,
            HAKUSPACE_HEALTH_REPORT: formatReport(),
            HAKUSPACE_HEALTH_SUMMARY: summaryLines.join("\n")
        }
        reporter.command = [
            "sh", "-c",
            'dir=${HAKUSPACE_HEALTH_LOG%/*}; mkdir -p "$dir" && printf "%s\\n" "$HAKUSPACE_HEALTH_REPORT" > "$HAKUSPACE_HEALTH_LOG.tmp" && mv -f "$HAKUSPACE_HEALTH_LOG.tmp" "$HAKUSPACE_HEALTH_LOG"; command -v notify-send >/dev/null 2>&1 && notify-send -u critical -a "HakuSpace" "Hikai Degraded Mode" "$HAKUSPACE_HEALTH_SUMMARY" || true'
        ]
        reporter.running = true
    }

    function resetMonitoring() {
        retryTimer.stop()
        graceTimer.stop()
        graceElapsed = false
        retryAttempts = 0
        reportedSignature = ""
        pendingSignature = ""
        degradedSinceMs = 0
    }

    function status() {
        return JSON.stringify({
            active: active,
            checking: hasIssues && !graceElapsed,
            degraded: degraded,
            issueCount: issueCount,
            issues: issues,
            retryAttempts: retryAttempts,
            degradedSinceMs: degradedSinceMs,
            lastCheckedAtMs: lastCheckedAtMs,
            logPath: logPath
        })
    }

    onActiveChanged: {
        resetMonitoring()
        if (hasIssues) {
            retryTimer.restart()
            graceTimer.restart()
        }
    }

    onHasIssuesChanged: {
        if (hasIssues) {
            if (!graceElapsed && !graceTimer.running) graceTimer.restart()
            if (retryAttempts < maxRetries && !retryTimer.running) retryTimer.restart()
        } else {
            resetMonitoring()
        }
    }

    onFaultSignatureChanged: {
        if (degraded && hasIssues) dispatchReport()
    }

    Component.onCompleted: {
        if (hasIssues) {
            retryTimer.restart()
            graceTimer.restart()
        }
    }

    property Timer retryTimer: Timer {
        interval: 15000
        repeat: true
        onTriggered: {
            if (!root.hasIssues || root.retryAttempts >= root.maxRetries) {
                stop()
                return
            }
            root.retryAttempts += 1
            root.retryFailingServices()
        }
    }

    property Timer graceTimer: Timer {
        interval: 60000
        repeat: false
        onTriggered: {
            if (!root.hasIssues) return
            root.retryTimer.stop()
            root.graceElapsed = true
            root.degradedSinceMs = Date.now()
            root.dispatchReport()
        }
    }

    property Process reporter: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: {
            if (root.degraded && root.pendingSignature && root.pendingSignature !== root.reportedSignature) {
                root.dispatchReport()
            }
        }
    }
}
