// Internal Hikai policy; developer harnesses may supply shorter durations.
function defaults() {
    // Keep freshness beyond the polling cadence with room for helper completion.
    var sampleMs = 300000
    return {sampleMs: sampleMs, warmupMs: 90000, baselineSamples: 3, baselineSampleMs: 15000,
        historyLimit: 24, idleMs: 30000, softGrowthMiB: 150, hardGrowthMiB: 300,
        gcCooldownMs: 1200000, observationMs: 20000, gcEvidenceMs: 600000, effectiveMiB: 20,
        ineffectiveCooldownMs: 7200000, recycleCooldownMs: 7200000,
        recycleWindowMs: 86400000, recycleLimit: 2, fdGrowthLimit: 32, fdClassificationMs: 900000,
        freshMs: sampleMs + 60000, debug: false, gpu: false, autoRecycle: true}
}
