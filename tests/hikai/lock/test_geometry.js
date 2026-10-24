const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const codePath = path.join(__dirname, '../../../src/home/.config/quickshell/hakuspace/components/lock/LockMotion.js');
const rawCode = fs.readFileSync(codePath, 'utf8').replace(/^\.pragma\s+library\s*/m, '');
const LM = {};
vm.createContext(LM);
vm.runInContext(rawCode, LM);

// 1. Responsive metrics across desktop, QHD, ultrawide, portrait, and compact viewports
for (const [vw, vh] of [[1920, 1080], [2560, 1440], [3440, 1440], [1080, 1920], [600, 800]]) {
    const m = LM.metrics(vw, vh);
    assert(m.orbitSize > 0 && m.orbitSize <= Math.min(vw, vh), `orbit fits viewport ${vw}x${vh}`);
    assert(m.ringThickness >= 20 && m.ringThickness <= 48, `ring thickness in range for ${vw}x${vh}`);
    assert(m.pillMaxWidth > 0 && m.pillMaxWidth <= m.coreWidth, `pill fits core for ${vw}x${vh}`);
    assert(m.clockPixelSize >= 56 && m.clockPixelSize <= 132, `clock size in range for ${vw}x${vh}`);
}

const mDesktop = LM.metrics(1920, 1080);

// 2. K0 Seed (entryProgress = 0): solid ink nucleus, attached protrusions submerged
const k0Orbit = LM.orbitGeometry(mDesktop, { entryProgress: 0 });
const k0Radius = (k0Orbit.right.x - k0Orbit.left.x) * 0.5;
assert(Math.abs(k0Orbit.strokeWidth - k0Radius * 2) < 1e-4, 'K0 seed has zero inner hole (solid nucleus)');

// 3. Asymmetric orbit extrusion (entryProgress = 0.25): top-right stretches before bottom-left
const kExtrude = LM.orbitGeometry(mDesktop, { entryProgress: 0.25 });
const cx = mDesktop.orbitSize * 0.5;
const cy = mDesktop.orbitSize * 0.5;
assert((kExtrude.right.x - cx) > (cx - kExtrude.left.x), 'Top-right stretches ahead of bottom-left during LockIn');

// 4. K4 Ready (entryProgress = 1): asymmetric Concept 20 silhouette and extruded blobs
const k4Orbit = LM.orbitGeometry(mDesktop, { entryProgress: 1 });
assert(Math.abs(k4Orbit.top.x - k4Orbit.bottom.x) > 4, 'Ready orbit has intentional horizontal asymmetry');
assert(Math.abs(k4Orbit.left.y - k4Orbit.right.y) > 4, 'Ready orbit has intentional vertical asymmetry');
assert(k4Orbit.beforeBlob.visible && k4Orbit.beforeBlob.width > 100, 'Top-right capsule lobe extruded');
assert(k4Orbit.afterBlob.visible && k4Orbit.afterBlob.width > 70, 'Bottom-left circle lobe extruded');

// 5. Idle breathing: asymmetric deformation and independent droplet phases
const idle0 = LM.orbitGeometry(mDesktop, { entryProgress: 1, idlePhase: 0.0 });
const idle1 = LM.orbitGeometry(mDesktop, { entryProgress: 1, idlePhase: 0.25 });
assert(Math.abs(idle1.right.x - idle0.right.x) > 1, 'Idle phase deforms orbit control points');
const drop0 = LM.dropletsGeometry(mDesktop, idle0, { entryProgress: 1, idlePhase: 0.0 });
const drop1 = LM.dropletsGeometry(mDesktop, idle1, { entryProgress: 1, idlePhase: 0.25 });
assert.strictEqual(drop0.length, 3, 'Three Concept 20 satellite droplets');
assert(Math.hypot(drop1[0].centerX - drop0[0].centerX, drop1[0].centerY - drop0[0].centerY) > 1, 'Droplets drift in idle');

// 6. Focus, Submit, Failure recoil, and Success closure on AuthPill & Orbit
const pillSeed = LM.authPillGeometry(mDesktop, { entryProgress: 0.26 });
const pillIdle = LM.authPillGeometry(mDesktop, { entryProgress: 1, focusProgress: 0 });
const pillFocus = LM.authPillGeometry(mDesktop, { entryProgress: 1, focusProgress: 1 });
const pillAuth = LM.authPillGeometry(mDesktop, { entryProgress: 1, focusProgress: 1, authPressure: 1 });
const pillFailCompress = LM.authPillGeometry(mDesktop, { entryProgress: 1, focusProgress: 1, failureImpulse: 0.14 });
const pillFailOvershoot = LM.authPillGeometry(mDesktop, { entryProgress: 1, focusProgress: 1, failureImpulse: 0.36 });
const pillSuccess = LM.authPillGeometry(mDesktop, { entryProgress: 1, focusProgress: 1, successProgress: 1 });

assert(Math.abs(pillSeed.width - pillSeed.height) < 2, 'Auth capsule originates as a round blob');
assert(pillFocus.width > pillIdle.width, 'Focus subtly expands capsule width');
assert(pillAuth.width < pillFocus.width, 'Submit compresses capsule horizontally');
assert(pillFailCompress.width < pillFocus.width * 0.94, 'Failure recoil first compresses capsule');
assert(pillFailOvershoot.width > pillFocus.width, 'Failure recoil rebounds with small overshoot');
assert(Math.abs(pillSuccess.width - pillSuccess.height) < 1, 'Success merges capsule back into circular core');

const k6Orbit = LM.orbitGeometry(mDesktop, { entryProgress: 1, successProgress: 1 });
assert(Math.abs(k6Orbit.top.x - k6Orbit.bottom.x) < 1e-4, 'Success closes orbit into symmetric circle');
assert((k6Orbit.right.x - k6Orbit.left.x) < (k4Orbit.right.x - k4Orbit.left.x) * 0.5, 'Success contracts orbit radius');

console.log('Lock geometry and liquid morph keyframe checks passed.');

// Reject invalid coordinates and sizes throughout both layer transitions and auth morphs.
function checkFiniteGeometry(value, label) {
    for (const [key, child] of Object.entries(value)) {
        const field = `${label}.${key}`;
        if (typeof child === 'number') {
            assert(Number.isFinite(child), `${field} must be finite`);
            if (['width', 'height', 'radius', 'strokeWidth'].includes(key)) {
                assert(child >= 0, `${field} must be nonnegative`);
            }
        } else if (child && typeof child === 'object') {
            checkFiniteGeometry(child, field);
        }
    }
}

// Exercise common output sizes, including 4K, compact, and portrait layouts.
for (const [vw, vh] of [[1920, 1080], [2560, 1440], [3440, 1440], [3840, 2160], [1280, 720], [600, 1000]]) {
    const m = LM.metrics(vw, vh);
    for (const progress of [0, 0.1, 0.25, 0.5, 0.75, 0.9, 1]) {
        for (const mode of ['capture', 'release']) {
            const wave = LM.layerSealGeometry(m, { progress, mode });
            checkFiniteGeometry(wave, `${vw}x${vh}.${mode}.${progress}`);
            assert.strictEqual(LM.layerSealGeometry(m, { progress, mode, reducedMotion: true }).visible,
                false, 'reduced motion never renders a viewport wave');
        }
        for (const state of [{ entryProgress: progress }, { entryProgress: 1, successProgress: progress }]) {
            const orbit = LM.orbitGeometry(m, state);
            checkFiniteGeometry(orbit, 'orbit');
            checkFiniteGeometry(LM.dropletsGeometry(m, orbit, state), 'droplets');
            checkFiniteGeometry(LM.authPillGeometry(m, state), 'pill');
        }
    }

    // The capture seed and release nucleus share the orbit's exact path and stroke at handoff.
    for (const [mode, progress, state] of [
        ['capture', 1, { entryProgress: 0 }],
        ['release', 0, { entryProgress: 1, successProgress: 1 }],
    ]) {
        const wave = LM.layerSealGeometry(m, { mode, progress });
        const orbit = LM.orbitGeometry(m, state);
        assert(Math.abs(wave.strokeWidth - orbit.strokeWidth) < 1e-5, `${mode} stroke handoff`);
        for (const key of ['top', 'right', 'bottom', 'left', 'c0a', 'c0b', 'c1a', 'c1b', 'c2a', 'c2b', 'c3a', 'c3b']) {
            assert(Math.abs(wave[key].x - orbit[key].x - (vw - m.orbitSize) / 2) < 1e-5, `${mode} ${key}.x handoff`);
            assert(Math.abs(wave[key].y - orbit[key].y - (vh - m.orbitSize) / 2) < 1e-5, `${mode} ${key}.y handoff`);
        }
    }
    const releaseEnd = LM.layerSealGeometry(m, { mode: 'release', progress: 1 });
    const innerRadius = releaseEnd.right.x - vw / 2 - releaseEnd.strokeWidth / 2;
    assert(innerRadius > Math.hypot(vw, vh) / 2, 'release front clears every viewport corner');
}

// Satellites are born at zero size, then shrink only after reaching the merge region.
const noEntry = { entryProgress: 0 };
const closed = { entryProgress: 1, successProgress: 1 };
for (const state of [noEntry, closed]) {
    const orbit = LM.orbitGeometry(mDesktop, state);
    assert(orbit.beforeBlob.width < 0.01 && orbit.afterBlob.width < 0.01, 'lobes have no full-size popping');
    for (const droplet of LM.dropletsGeometry(mDesktop, orbit, state)) {
        assert(droplet.width < 0.01 && !droplet.visible, 'satellites have spatial birth and death');
    }
    assert(LM.authPillGeometry(mDesktop, state).scale < 0.01, 'pill grows from and merges into zero size');
}
const readyForInput = LM.authPillGeometry(mDesktop, { entryProgress: (1150 - 525) / 1675 });
assert(readyForInput.width * readyForInput.scale > 180 && readyForInput.inputOpacity > 0,
    'pill has usable width and visible password content at the input-ready milestone');

// Visual components cannot own authentication or perform session unlocks.
const lockDir = path.dirname(codePath);
for (const name of ['LockLayerTransition.qml', 'LiquidSealWave.qml']) {
    const source = fs.readFileSync(path.join(lockDir, name), 'utf8');
    assert(!/LockState|PamContext|WlSessionLock|Timer\s*\{/.test(source), `${name} remains security-dumb`);
}
for (const name of fs.readdirSync(lockDir).filter(name => name.endsWith('.qml'))) {
    const source = fs.readFileSync(path.join(lockDir, name), 'utf8');
    assert(!/locked\s*=\s*false|_completeUnlockAfterPamSuccess/.test(source), `${name} cannot unlock`);
}
const surfaceSource = fs.readFileSync(path.join(lockDir, 'LockSurface.qml'), 'utf8');
assert(/id: opaqueCover\s+anchors.fill: parent\s+color: root.bgInkColor\s+opacity: 1.0/.test(surfaceSource),
    'frame-zero opaque cover remains constant');
console.log('Liquid seal geometry, handoff, reduced motion, and security guards passed.');
