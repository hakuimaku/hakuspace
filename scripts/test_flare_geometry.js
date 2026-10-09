/**
 * @file test_flare_geometry.js
 * @brief Automated Node.js unit tests for FlareGeometry.js math module.
 * 
 * Executed automatically during `scripts/precommit_check.sh`.
 */

const fs = require('fs');
const path = require('path');

// Read the QML JS file and strip Qt QML's `.pragma library` directive for Node.js execution
const codePath = path.join(__dirname, '../src/home/.config/quickshell/hakuspace/components/flare/FlareGeometry.js');
let code = fs.readFileSync(codePath, 'utf8');
code = code.replace(/^\s*\.pragma\s+library\s*$/m, '');

// Evaluate the code in a sandbox environment
const sandbox = { module: { exports: {} } };
const fn = new Function('module', code);
fn(sandbox.module);

const FlareGeometry = sandbox.module.exports;

let failCount = 0;
function assert(condition, message) {
    if (!condition) {
        console.error("FAIL: " + message);
        failCount++;
    } else {
        console.log("PASS: " + message);
    }
}

console.log("--- Testing resolveSpan ---");
// 1. Left boundary collision (expand and keep right edge)
let res = FlareGeometry.resolveSpan({
    anchorStart: 10, anchorEnd: 50, // center = 30
    contentW: 100, padX: 0, minW: 0, maxW: 1000,
    bounds: { start: 0, end: 1920 },
    snap: 40
});
// center 30, reqW 100 -> eL = -20, eR = 80
// eL < bStart + snap (0 + 40 = 40). eL becomes 0, eR becomes max(80, 0 + 100) = 100
assert(res.start === 0 && res.end === 100, `Left boundary collision: expected 0..100, got ${res.start}..${res.end}`);

// 2. Right boundary collision
res = FlareGeometry.resolveSpan({
    anchorStart: 1890, anchorEnd: 1910, // center = 1900
    contentW: 100, padX: 0, minW: 0, maxW: 1000,
    bounds: { start: 0, end: 1920 },
    snap: 40
});
// center 1900, eL = 1850, eR = 1950
// eR > 1920 - 40 (1880). eR = 1920, eL = min(1850, 1920 - 100) = 1820
assert(res.start === 1820 && res.end === 1920, `Right boundary collision: expected 1820..1920, got ${res.start}..${res.end}`);

// 3. Clamp when maxW is larger than screen bounds
res = FlareGeometry.resolveSpan({
    anchorStart: 500, anchorEnd: 600,
    contentW: 3000, padX: 0, minW: 0, maxW: 1500, // contentW is 3000 but maxW is 1500
    bounds: { start: 0, end: 1000 }, // window is only 1000
    snap: 0
});
// center = 550, reqW = 1500
// eL = -200, eR = 1300
// eL < 0 -> eL = 0, eR = 1500 (since max(1300, 1500) = 1500)
// eR > 1000 -> eR = 1000, eL = min(0, -500) = -500
// After clamping to bounds: eL = 0, eR = 1000.
// Is eR - eL > maxW? 1000 - 0 = 1000 <= 1500. So it stays 0..1000.
assert(res.start === 0 && res.end === 1000, `Clamp maxW > screen: expected 0..1000, got ${res.start}..${res.end}`);

console.log("\n--- Testing hugFactors ---");
// 4. Proximity factors (kS/kE) at 0, 0.25, 0.5, 1.0
let hf = FlareGeometry.hugFactors(0, 100, { bounds: { start: 0, end: 100 }, rf: 20 });
assert(hf.kS === 0 && hf.kE === 0, `hugFactors touching bounds: kS=${hf.kS}, kE=${hf.kE}`);

hf = FlareGeometry.hugFactors(5, 95, { bounds: { start: 0, end: 100 }, rf: 20 });
assert(hf.kS === 0.25 && hf.kE === 0.25, `hugFactors 0.25: kS=${hf.kS}, kE=${hf.kE}`);

hf = FlareGeometry.hugFactors(10, 90, { bounds: { start: 0, end: 100 }, rf: 20 });
assert(hf.kS === 0.5 && hf.kE === 0.5, `hugFactors 0.5: kS=${hf.kS}, kE=${hf.kE}`);

hf = FlareGeometry.hugFactors(20, 80, { bounds: { start: 0, end: 100 }, rf: 20 });
assert(hf.kS === 1 && hf.kE === 1, `hugFactors 1.0: kS=${hf.kS}, kE=${hf.kE}`);

hf = FlareGeometry.hugFactors(50, 50, { bounds: { start: 0, end: 100 }, rf: 20 });
assert(hf.kS === 1 && hf.kE === 1, `hugFactors > 1.0 (clamped): kS=${hf.kS}, kE=${hf.kE}`);

console.log("\n--- Testing pieces ---");
// 5. pieces() returns correct ear/foot positions and radii
let p = FlareGeometry.pieces({ start: 100, end: 200, height: 50, kS: 0, kE: 1 }, { r: 20, rf: 20 });
// kS = 0 (touching left edge): earStart scale 0, footStart scale 1. radiusStart 0
// kE = 1 (far from right edge): earEnd scale 1, footEnd scale 0. radiusEnd 20
assert(p.earStart.u === 80 && p.earStart.scale === 0, `earStart at kS=0: u=${p.earStart.u}, scale=${p.earStart.scale}`);
assert(p.footStart.u === 100 && p.footStart.scale === 1, `footStart at kS=0: u=${p.footStart.u}, scale=${p.footStart.scale}`);
assert(p.radiusStart === 0, `radiusStart at kS=0: ${p.radiusStart}`);
assert(p.earEnd.u === 200 && p.earEnd.scale === 1, `earEnd at kE=1: u=${p.earEnd.u}, scale=${p.earEnd.scale}`);
assert(p.footEnd.u === 180 && p.footEnd.scale === 0, `footEnd at kE=1: u=${p.footEnd.u}, scale=${p.footEnd.scale}`);
assert(p.radiusEnd === 20, `radiusEnd at kE=1: ${p.radiusEnd}`);

console.log("\n--- Testing Edge Cases ---");
// 6. Null and invalid arguments handling
let nullRes = FlareGeometry.resolveSpan(null);
assert(nullRes.start === 0 && nullRes.end === 0, `null args for resolveSpan handled safely`);

let nullHf = FlareGeometry.hugFactors(null, null, null);
assert(nullHf.kS === 0 && nullHf.kE === 0, `null args for hugFactors handled safely`);

let nullP = FlareGeometry.pieces(null, null);
assert(nullP.earStart.u === 0 && nullP.earStart.scale === 0, `null args for pieces handled safely`);

// 7. Division by zero protection (rf = 0)
let zeroRf = FlareGeometry.hugFactors(10, 90, { bounds: { start: 0, end: 100 }, rf: 0 });
assert(!isNaN(zeroRf.kS) && !isNaN(zeroRf.kE), `rf=0 does not return NaN (kS=${zeroRf.kS})`);

if (failCount > 0) {
    console.error(`\nFAILED ${failCount} tests.`);
    process.exit(1);
} else {
    console.log(`\nALL TESTS PASSED!`);
}
