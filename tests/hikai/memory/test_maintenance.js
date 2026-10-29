// Exercise the production state machine without QML clocks or synthetic GC claims.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const shell = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(shell, 'config/Memory.js'), 'utf8'), context);
vm.runInContext(fs.readFileSync(path.join(shell, 'services/MemoryPolicy.js'), 'utf8'), context);
const policy = context.defaults();
assert.ok(policy.freshMs > policy.sampleMs, 'sample freshness must outlast the polling interval');
assert.ok(policy.fdClassificationMs >= 15 * 60 * 1000, 'descriptor scans must remain sparse');
const sample = {rssKiB: 1024, pssKiB: null, gpuResidentKiB: null, fdCount: 20, threadCount: 4, childCount: 1};
assert.equal(context.validSample(sample), true);
for (const invalid of [{rssKiB: NaN}, {rssKiB: 0}, {fdCount: -1}, {threadCount: 0.5}, {pssKiB: undefined}])
    assert.equal(context.validSample({...sample, ...invalid}), false);
const now = 100000000;
const data = {enabled: true, baselineReady: true, fdGrowth: 0, observing: false,
    sampleAge: 0, growth: 0, safe: true, ineffective: false, lastGcAt: 0,
    lastRecycleAt: 0, recycleEligible: true, recycleBlocked: false, gcEvidenceFresh: true};
// Each override represents an independent maintenance decision.
function state(overrides) { return context.decision(policy, {...data, ...overrides}, now); }
assert.equal(state({enabled: false}), 'disabled');
assert.equal(state({baselineReady: false, growth: 1000}), 'warming-up');
assert.equal(state({}), 'normal');
assert.equal(state({growth: 151}), 'soft-pressure');
assert.equal(state({growth: 151, safe: false}), 'gc-pending');
assert.equal(state({growth: 500, observing: true}), 'gc-observing');
assert.equal(state({growth: 500, lastGcAt: now - 1}), 'cooldown');
assert.equal(state({growth: 500, ineffective: true}), 'recycle-pending');
assert.equal(state({growth: 500, ineffective: true, safe: false}), 'hard-pressure');
assert.equal(state({growth: 500, ineffective: true, recycleEligible: false}), 'hard-pressure');
assert.equal(state({growth: 500, ineffective: true, recycleBlocked: true}), 'cooldown');
assert.equal(state({growth: 500, ineffective: true, gcEvidenceFresh: false, lastGcAt: now - 1}), 'cooldown');
assert.equal(state({growth: 200, ineffective: true, lastGcAt: now - policy.gcCooldownMs}), 'cooldown');
assert.equal(state({growth: 500, fdGrowth: policy.fdGrowthLimit, ineffective: true}), 'fd-growth');
assert.equal(state({growth: 500, sampleAge: policy.freshMs + 1}), 'stale');
assert.equal(state({growth: 151, sampleAge: policy.sampleMs + 1}), 'soft-pressure');
assert.equal(state({growth: 200, lastRecycleAt: now - 1}), 'cooldown');
assert.equal(state({growth: 200, lastGcAt: now + 1}), 'cooldown');
// Expired ineffective evidence under hard pressure must permit a fresh GC after its normal cooldown.
const ineffectiveGc = context.gcResult({rssMiB: 600, pssMiB: 500}, {rssMiB: 600, pssMiB: 500}, policy.effectiveMiB);
// Keep the failed collection inside the ineffective backoff while expiring its recycle evidence.
const gcAt = now - policy.gcCooldownMs;
// Observation completes after GC and determines the age of the evidence.
const postGcAt = gcAt + policy.observationMs;
// Reproduce the runtime decision input after a failed collection ages out.
const expiredHardPressure = {growth: policy.hardGrowthMiB + 1, ineffective: ineffectiveGc.ineffective,
    lastGcAt: gcAt, gcEvidenceFresh: now - postGcAt <= policy.gcEvidenceMs};
assert.equal(expiredHardPressure.gcEvidenceFresh, false);
assert.ok(now - gcAt < policy.ineffectiveCooldownMs);
assert.equal(state(expiredHardPressure), 'soft-pressure');
assert.equal(state({...expiredHardPressure, safe: false}), 'gc-pending');
assert.equal(state({...expiredHardPressure, lastGcAt: gcAt + 1}), 'cooldown');
assert.equal(state({...expiredHardPressure, growth: policy.softGrowthMiB + 1}), 'cooldown');
assert.equal(state({...expiredHardPressure, fdGrowth: policy.fdGrowthLimit}), 'fd-growth');
assert.equal(state({...expiredHardPressure, lastRecycleAt: now - 1}), 'cooldown');
// Keep classification sparse through successive samples of the same FD anomaly.
assert.equal(context.fdClassificationDue(policy, policy.fdGrowthLimit, false, 0, now), true);
for (const elapsed of [0, policy.sampleMs, policy.fdClassificationMs - 1])
    assert.equal(context.fdClassificationDue(policy, policy.fdGrowthLimit, true, now, now + elapsed), false);
assert.equal(context.fdClassificationDue(policy, policy.fdGrowthLimit, true, now, now + policy.fdClassificationMs), true);
assert.equal(context.fdClassificationDue(policy, 0, false, 0, now), false);
assert.equal(context.fdClassificationDue(policy, policy.fdGrowthLimit, true, now, now - 1), false);
assert.equal(context.fdClassificationDue({...policy, debug: true}, 0, false, 0, now), true);
assert.equal(context.fdClassificationDue({...policy, debug: true}, 0, true, now, now + policy.sampleMs), false);
assert.equal(context.median([300, 100, 200]), 200);
assert.equal(context.median([100, 200]), 150);
const before = {rssMiB: 600, pssMiB: 500};
assert.equal(context.gcResult(before, {rssMiB: 550, pssMiB: 490}, 20).ineffective, true);
assert.equal(context.gcResult(before, {rssMiB: 550, pssMiB: null}, 20).basis, 'rss');
assert.equal(context.gcResult(before, {rssMiB: 650, pssMiB: 450}, 20).freedMiB, 50);
console.log('Memory policy checks passed (T1–T7/T9 decisions, PSS fallback).');
