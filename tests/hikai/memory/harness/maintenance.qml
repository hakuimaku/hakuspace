import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
    id: root
    // Short durations exercise the real GC/helper/reload path in a disposable engine.
    Component.onCompleted: {
        Quickshell.watchFiles = false
        MemoryMaintenance.policy = Object.assign({}, MemoryMaintenance.policy,
            {warmupMs: 400, baselineSampleMs: 100, idleMs: 100, sampleMs: 250,
                observationMs: 200, gcEvidenceMs: 1000, gcCooldownMs: 2000, ineffectiveCooldownMs: 4000,
                fdClassificationMs: 1200,
                recycleCooldownMs: 5000, recycleWindowMs: 60000, autoRecycle: false})
        MemoryMaintenance.activitySafe = true
        MemoryMaintenance.start()
    }
    IpcHandler {
        target: "memory"
        function status(): string { return MemoryMaintenance.status() }
        function baseline(): string { return JSON.stringify(MemoryMaintenance.baseline) }
        function collect(): string { return MemoryMaintenance.collect() }
        function recycle(): string { return MemoryMaintenance.recycle() }
    }
    // Tests change telemetry thresholds, never bypass the service's safety checks.
    IpcHandler {
        target: "maintenanceTest"
        function safe(value: bool) { MemoryMaintenance.activitySafe = value }
        function pressure() {
            MemoryMaintenance.baseline = Object.assign({}, MemoryMaintenance.baseline, {rssMiB: 1})
            MemoryMaintenance.policy = Object.assign({}, MemoryMaintenance.policy, {softGrowthMiB: 1, hardGrowthMiB: 2, effectiveMiB: 100000})
            MemoryMaintenance.requestSample("observe")
        }
        function allowRecycle() {
            MemoryMaintenance.policy = Object.assign({}, MemoryMaintenance.policy, {autoRecycle: true})
            MemoryMaintenance.requestSample("observe")
        }
        function fdGrowth() {
            MemoryMaintenance.baseline = Object.assign({}, MemoryMaintenance.baseline, {rssMiB: 1, fdCount: -100})
            MemoryMaintenance.requestSample("observe")
        }
        function clearPressure() {
            MemoryMaintenance.baseline = Object.assign({}, MemoryMaintenance.baseline,
                {rssMiB: MemoryMaintenance.metrics.rssMiB, fdCount: MemoryMaintenance.metrics.fdCount})
            MemoryMaintenance.requestSample("observe")
        }
        function stop() { MemoryMaintenance.stop() }
        function quit() { Qt.quit() }
    }
}
