pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config/Memory.js" as Config
import "MemoryPolicy.js" as Policy

QtObject {
    id: root
    // The Hikai-only host supplies activity data without importing UI owners here.
    property bool enabled: false
    // Receive the host activity gate.
    property bool activitySafe: false
    // Report heavy trees still loaded across outputs.
    property int loadedSurfaces: 0
    // Label the current shell interaction in telemetry.
    property string activeLayer: ""
    // Keep blocker names without retaining UI objects.
    property var blockers: []
    // Load the central developer policy.
    property var policy: Config.defaults()
    // Expose the current maintenance decision.
    property string state: "disabled"
    // Track completion of the startup quieting period.
    property bool warm: false
    // Track uninterrupted shell activity quiet.
    property bool quiet: false
    // Combine warmup, baseline, activity and reservation gates.
    readonly property bool maintenanceSafe: enabled && warm && baselineReady && activitySafe && quiet && !reserving
    // Allow pressure decisions only after baseline acquisition.
    property bool baselineReady: false
    // Retain only the samples needed for the initial median.
    property var baselineSamples: []
    // Keep the engine generation memory and descriptor reference.
    property var baseline: ({rssMiB: null, pssMiB: null, fdCount: null})
    // Publish the latest process counters with nullable memory fields.
    property var metrics: ({rssMiB: null, pssMiB: null, gpuResidentMiB: null, fdCount: null, threadCount: null, childCount: null})
    // Keep a bounded rolling sample window.
    property var history: []
    // Keep a bounded maintenance event window.
    property var events: []
    // Timestamp the most recent successful read.
    property double sampledAt: 0
    // Expose helper failures without failing shell startup.
    property string error: ""
    // GC observations belong to this engine generation, never a preceding engine.
    property int gcCount: 0
    // Enforce collection cooldown from the actual GC request.
    property double lastGcAt: 0
    // Retain the fresh counters measured before collection.
    property var preGc: null
    // Retain counters measured after the observation delay.
    property var postGc: null
    // Report signed reclaim rather than hiding allocation growth.
    property var lastGcFreedMiB: null
    // Identify the paired memory counter used for reclaim.
    property string gcMetric: ""
    // Qualify ineffective GC only within its pressure episode.
    property bool ineffective: false
    // Prevent effects while post-GC evidence is pending.
    property bool observing: false
    // Prevent competing effects during a persisted recycle reservation.
    property bool reserving: false
    // Persisted attempts remain effective even if reload fails or state changes mid-request.
    property var protection: ({lastRecycleTimestamp: 0, recycleCount: 0, recentRecycles: []})
    // Fail closed when persisted loop protection cannot be read.
    property bool protectionReady: false
    // Query runtime version and protection once per singleton.
    property bool initialized: false
    // Permit recycling only for a verified supported runtime.
    property bool versionEligible: false
    // Report the exact release returned by the running executable.
    property string version: "unknown"
    // Explain a disabled runtime recycle guard.
    property string versionReason: "runtime version not checked"
    // Track whether descriptor classification has started for the current anomaly.
    property bool fdClassified: false
    // Identify the age of descriptor classification.
    property double fdClassifiedAt: 0
    // Retain category counts without filesystem paths.
    property var fdClasses: ({})
    // Compare RSS against the established median.
    readonly property real growthRssMiB: baselineReady ? metrics.rssMiB - baseline.rssMiB : 0
    // Compare descriptor use against the baseline.
    readonly property int fdGrowth: baselineReady ? metrics.fdCount - baseline.fdCount : 0
    // Require runtime, persistence and configured recycle permission.
    readonly property bool recycleEligible: versionEligible && protectionReady && policy.autoRecycle
    onFdGrowthChanged: if (!policy.debug && fdGrowth < policy.fdGrowthLimit) fdClassified = false

    // Resolve the same helper in deployed and source-tree layouts.
    function command(args) {
        return ["sh", "-c", 'script=$1; [ -f "$script" ] || script=$2; shift 2; exec python3 "$script" "$@"',
            "--", Env.binDir + "/hikai_memory_ctl.py", Quickshell.shellPath("../../../../core/backend/system/hikai_memory_ctl.py")].concat(args)
    }

    // Log decisions and bounded event metadata, never every production sample.
    function event(name, detail) {
        events = events.concat([{at: Date.now(), event: name, detail: detail || ""}]).slice(-policy.historyLimit)
        console.info("Hikai memory: " + name + (detail ? " — " + detail : ""))
    }

    // Re-enter warmup after every host activation; Classic starts no sampling work.
    function start() {
        if (enabled) return
        enabled = true
        warm = false; quiet = false; baselineReady = false; baselineSamples = []
        state = "warming-up"
        warmup.restart()
        if (activitySafe) idleDelay.restart()
        requestSample("observe")
    }
    // Stop every owned timer and helper when Hikai relinquishes its runtime.
    function stop() {
        enabled = false
        warmup.stop(); polling.stop(); observation.stop(); idleDelay.stop()
        reader.running = false; writer.running = false
        observing = false; reserving = false
        state = "disabled"
    }

    // Require uninterrupted shell quiet, including completed visual teardown.
    onActivitySafeChanged: {
        quiet = false
        idleDelay.stop()
        if (enabled && activitySafe) idleDelay.restart()
    }

    // Serialize finite reads; an observation cannot be overwritten by a polling tick.
    function requestSample(purpose) {
        if (!enabled || reader.running || reserving) return false
        reader.purpose = purpose
        var args = ["sample", String(Quickshell.processId)]
        if (!initialized) args.push("--initialize")
        if (policy.gpu) args.push("--gpu")
        if (Policy.fdClassificationDue(policy, fdGrowth, fdClassified, fdClassifiedAt, Date.now())) args.push("--classify")
        reader.command = command(args)
        reader.running = true
        return true
    }

    // Establish the idle baseline only after warmup and several independent samples.
    function establishBaseline() {
        if (baselineReady || !warm || !activitySafe || !quiet) return
        baselineSamples = baselineSamples.concat([metrics]).slice(-policy.baselineSamples)
        if (baselineSamples.length < policy.baselineSamples) return
        var pss = baselineSamples.map(function(row) { return row.pssMiB }).filter(function(value) { return value !== null })
        baseline = {rssMiB: Policy.median(baselineSamples.map(function(row) { return row.rssMiB })),
            pssMiB: pss.length === baselineSamples.length ? Policy.median(pss) : null,
            fdCount: Policy.median(baselineSamples.map(function(row) { return row.fdCount }))}
        baselineReady = true
        event("baseline established", JSON.stringify(baseline))
    }

    // Derive cooldown/loop gates with conservative behavior after clock rollback.
    function recycleBlocked(now) {
        return (protection.lastRecycleTimestamp > 0 && now - protection.lastRecycleTimestamp < policy.recycleCooldownMs)
            || protection.recentRecycles.filter(function(stamp) { return now - stamp < policy.recycleWindowMs }).length >= policy.recycleLimit
    }

    // A single state machine decides effects from fresh telemetry and current activity.
    function evaluate() {
        if (reserving) return
        var now = Date.now()
        var next = Policy.decision(policy, {enabled: enabled, baselineReady: baselineReady,
            fdGrowth: fdGrowth, observing: observing, sampleAge: now - sampledAt,
            growth: growthRssMiB, safe: maintenanceSafe, ineffective: ineffective,
            gcEvidenceFresh: postGc !== null && now - postGc.at <= policy.gcEvidenceMs,
            lastGcAt: lastGcAt, lastRecycleAt: protection.lastRecycleTimestamp,
            recycleEligible: recycleEligible, recycleBlocked: recycleBlocked(now)}, now)
        if (next !== state) {
            if (next === "fd-growth") event("FD anomaly detected", "delta=" + fdGrowth)
            else if (next === "soft-pressure") event("soft pressure detected", "growthMiB=" + growthRssMiB.toFixed(1))
            else if (next === "gc-pending") event("GC skipped because unsafe", blockers.join(",") || "waiting for shell quiet")
            else if (next === "hard-pressure") event("hard pressure; recycle skipped", maintenanceSafe ? versionReason || "policy disabled" : blockers.join(",") || "waiting for shell quiet")
            state = next
        }
        if (next === "soft-pressure") collectNow()
        else if (next === "recycle-pending") reserveRecycle()
        else if (next === "fd-growth" && !reader.running
            && Policy.fdClassificationDue(policy, fdGrowth, fdClassified, fdClassifiedAt, now)) requestSample("classify")
    }

    // Manual collection bypasses pressure thresholds, retaining safety and cooldown gates.
    function collect() {
        if (!maintenanceSafe) return "rejected: unsafe shell state"
        if (fdGrowth >= policy.fdGrowthLimit) return "rejected: fd-growth"
        if (observing || reader.running || (lastGcAt && Date.now() - lastGcAt < policy.gcCooldownMs)
                || (protection.lastRecycleTimestamp && Date.now() - protection.lastRecycleTimestamp < policy.gcCooldownMs)) return "rejected: cooldown or busy"
        return requestSample("collect") ? "scheduled" : "rejected: busy"
    }

    // Save a fresh pre-GC pair and let the owner event loop settle before observation.
    function collectNow() {
        if (!maintenanceSafe || observing || fdGrowth >= policy.fdGrowthLimit) return
        preGc = Object.assign({at: sampledAt, pressure: growthRssMiB > policy.softGrowthMiB}, metrics)
        postGc = null; lastGcFreedMiB = null; ineffective = false
        lastGcAt = Date.now(); ++gcCount
        observing = true; state = "gc-observing"
        event("GC requested", "rssMiB=" + metrics.rssMiB.toFixed(1))
        gc()
        observation.restart()
    }

    // Version and persisted loop gates apply to manual engine recycling as well.
    function recycle() {
        if (!maintenanceSafe) return "rejected: unsafe shell state"
        if (!recycleEligible) return "rejected: " + (versionReason || "recycle disabled by policy")
        if (observing || reader.running || fdGrowth >= policy.fdGrowthLimit || recycleBlocked(Date.now())) return "rejected: fd-growth, observation, cooldown or busy"
        return requestSample("recycle") ? "scheduled" : "rejected: busy"
    }

    // The helper atomically reserves an attempt before Quickshell can create a new engine.
    function reserveRecycle() {
        if (!maintenanceSafe || !recycleEligible || observing || fdGrowth >= policy.fdGrowthLimit || recycleBlocked(Date.now())) return
        reserving = true; state = "recycle-pending"
        writer.command = command(["reserve", String(Quickshell.processId), "--cooldown-ms", String(policy.recycleCooldownMs),
            "--window-ms", String(policy.recycleWindowMs), "--limit", String(policy.recycleLimit)])
        writer.running = true
    }

    // Structured IPC contains data snapshots only, with explicit sample age and GC basis.
    function status() {
        return JSON.stringify({state: state, rssMiB: metrics.rssMiB, pssMiB: metrics.pssMiB,
            gpuResidentMiB: metrics.gpuResidentMiB, baselineRssMiB: baseline.rssMiB, baselinePssMiB: baseline.pssMiB,
            growthRssMiB: growthRssMiB, softThresholdMiB: baselineReady ? baseline.rssMiB + policy.softGrowthMiB : null,
            hardThresholdMiB: baselineReady ? baseline.rssMiB + policy.hardGrowthMiB : null,
            fdCount: metrics.fdCount, fdGrowth: fdGrowth, fdClasses: fdClasses, fdClassifiedAt: fdClassifiedAt,
            threadCount: metrics.threadCount, childCount: metrics.childCount, loadedSurfaces: loadedSurfaces,
            activeLayer: activeLayer, maintenanceSafe: maintenanceSafe, blockers: blockers,
            gcCount: gcCount, lastGcAt: lastGcAt, lastGcFreedMiB: lastGcFreedMiB, gcMetric: gcMetric,
            gcIneffective: postGc !== null && lastGcFreedMiB < policy.effectiveMiB,
            preGc: preGc, postGc: postGc, recycleCount: protection.recycleCount,
            lastRecycleTimestamp: protection.lastRecycleTimestamp,
            recentRecycleCount: protection.recentRecycles.filter(function(stamp) { return Date.now() - stamp < policy.recycleWindowMs }).length,
            recycleEligible: recycleEligible, version: version, versionReason: versionReason,
            sampleAt: sampledAt, sampleAgeMs: sampledAt ? Date.now() - sampledAt : null, error: error,
            history: history, events: events})
    }

    // Timers schedule measurements and quiet periods; none reloads unconditionally.
    property Timer warmup: Timer {
        interval: root.policy.warmupMs
        onTriggered: { root.warm = true; root.requestSample("observe"); polling.restart() }
    }
    property Timer idleDelay: Timer {
        interval: root.policy.idleMs
        onTriggered: {
            root.quiet = true
            if (root.warm && !root.observing) root.requestSample("observe")
        }
    }
    property Timer polling: Timer {
        interval: !root.baselineReady && root.activitySafe && root.quiet ? root.policy.baselineSampleMs : root.policy.sampleMs
        repeat: true
        onTriggered: root.requestSample(root.observing ? "post-gc" : "observe")
    }
    property Timer observation: Timer {
        interval: root.policy.observationMs
        onTriggered: root.requestSample("post-gc")
    }
    property Process reader: Process {
        property string purpose: "observe"
        stdout: StdioCollector { id: sampleOut }
        onExited: code => {
            if (!root.enabled) return
            try {
                var value = JSON.parse(sampleOut.text)
                if (code !== 0 || value.error) throw new Error(value.error || "sampling failed")
                if (!Policy.validSample(value)) throw new Error("invalid telemetry counters")
                root.error = ""
                if (!root.initialized) {
                    root.version = value.version
                    root.versionEligible = value.recycleEligible === true
                    root.versionReason = value.versionReason
                    root.protectionReady = value.protectionReady === true
                    if (value.protection) root.protection = value.protection
                    root.initialized = true
                    if (!root.recycleEligible) root.event("recycle disabled", root.versionReason || "policy disabled")
                }
                root.metrics = {rssMiB: value.rssKiB / 1024, pssMiB: value.pssKiB === null ? null : value.pssKiB / 1024,
                    gpuResidentMiB: value.gpuResidentKiB === null ? null : value.gpuResidentKiB / 1024,
                    fdCount: value.fdCount, threadCount: value.threadCount, childCount: value.childCount}
                root.sampledAt = Date.now()
                // A recovered pressure episode cannot authorize a later unrelated recycle.
                if (root.baselineReady && root.growthRssMiB <= root.policy.softGrowthMiB) root.ineffective = false
                if (value.fdClasses) { root.fdClasses = value.fdClasses; root.fdClassified = true; root.fdClassifiedAt = root.sampledAt }
                root.history = root.history.concat([Object.assign({at: root.sampledAt, activeLayer: root.activeLayer,
                    loadedSurfaces: root.loadedSurfaces}, root.metrics)]).slice(-root.policy.historyLimit)
                if (root.policy.debug) console.info("Hikai memory sample: " + JSON.stringify(root.metrics))
                root.establishBaseline()
                if (purpose === "post-gc" && root.observing && Date.now() - root.lastGcAt >= root.policy.observationMs) {
                    root.postGc = Object.assign({at: root.sampledAt}, root.metrics)
                    var result = Policy.gcResult(root.preGc, root.postGc, root.policy.effectiveMiB)
                    root.lastGcFreedMiB = result.freedMiB; root.gcMetric = result.basis
                    root.ineffective = result.ineffective && root.preGc.pressure && root.growthRssMiB > root.policy.softGrowthMiB
                    root.observing = false
                    root.event("GC result", JSON.stringify(result))
                }
                if (purpose === "collect" && root.fdGrowth < root.policy.fdGrowthLimit) root.collectNow()
                else if (purpose === "recycle" && root.fdGrowth < root.policy.fdGrowthLimit) root.reserveRecycle()
                else root.evaluate()
            } catch (exception) {
                root.error = String(exception)
                root.state = "stale"
                root.event("telemetry unavailable", root.error)
            }
        }
    }
    property Process writer: Process {
        stdout: StdioCollector { id: reserveOut }
        onExited: code => {
            if (!root.enabled) return
            root.reserving = false
            try {
                var value = JSON.parse(reserveOut.text)
                if (code !== 0 || value.error) throw new Error(value.error || "reservation failed")
                root.protection = value.protection
                // Activity can change while the helper writes; recheck before engine teardown.
                if (!root.maintenanceSafe || root.fdGrowth >= root.policy.fdGrowthLimit) {
                    root.event("recycle skipped", "shell became unsafe; reservation retained")
                    root.evaluate()
                    return
                }
                root.event("recycle requested", "attempt=" + root.protection.recycleCount)
                Quickshell.reload(false)
            } catch (exception) {
                root.error = String(exception); root.protectionReady = false
                root.event("recycle skipped", root.error)
                root.evaluate()
            }
        }
    }
}
