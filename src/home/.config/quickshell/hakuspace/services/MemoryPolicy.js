// Compute a median without mutating the bounded sample history.
function median(values) {
    var sorted = values.slice().sort(function(a, b) { return a - b })
    var middle = Math.floor(sorted.length / 2)
    return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

// Reject malformed helper replies before they can establish a baseline or request GC.
function validSample(value) {
    return Number.isFinite(value.rssKiB) && value.rssKiB > 0
        && ["pssKiB", "gpuResidentKiB"].every(function(key) {
            return value[key] === null || (Number.isFinite(value[key]) && value[key] >= 0)
        }) && ["fdCount", "threadCount", "childCount"].every(function(key) {
            return Number.isInteger(value[key]) && value[key] >= 0
        })
}

// Refresh descriptor categories sparsely while an anomaly or debug sampling persists.
function fdClassificationDue(policy, growth, classified, classifiedAt, now) {
    return (policy.debug || growth >= policy.fdGrowthLimit)
        && (!classified || now - classifiedAt >= policy.fdClassificationMs)
}

// Keep decisions independent of QML timers and effects for deterministic tests.
function decision(policy, data, now) {
    if (!data.enabled) return "disabled"
    if (!data.baselineReady) return "warming-up"
    if (data.fdGrowth >= policy.fdGrowthLimit) return "fd-growth"
    if (data.observing) return "gc-observing"
    if (data.sampleAge > policy.freshMs) return "stale"
    if (data.growth <= policy.softGrowthMiB) return "normal"
    if (data.ineffective && data.gcEvidenceFresh && data.growth > policy.hardGrowthMiB) {
        if (!data.recycleEligible) return "hard-pressure"
        if (data.recycleBlocked) return "cooldown"
        return data.safe ? "recycle-pending" : "hard-pressure"
    }
    // Hard pressure needs new GC evidence on the normal cooldown after old evidence expires.
    var cooldown = data.ineffective && data.growth <= policy.hardGrowthMiB ? policy.ineffectiveCooldownMs : policy.gcCooldownMs
    if ((data.lastGcAt && now - data.lastGcAt < cooldown)
            || (data.lastRecycleAt && now - data.lastRecycleAt < policy.gcCooldownMs)) return "cooldown"
    return data.safe ? "soft-pressure" : "gc-pending"
}

// Compare the same memory counter on both sides; PSS is preferred when available.
function gcResult(before, after, effectiveMiB) {
    var usePss = before.pssMiB !== null && after.pssMiB !== null
    var freed = (usePss ? before.pssMiB - after.pssMiB : before.rssMiB - after.rssMiB)
    return {freedMiB: freed, basis: usePss ? "pss" : "rss", ineffective: freed < effectiveMiB}
}
