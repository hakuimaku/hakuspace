.pragma library

// Clamp a numeric value to [minVal, maxVal].
function clamp(v, minVal, maxVal) {
    return Math.max(minVal, Math.min(maxVal, v))
}

// Linear interpolation between a and b.
function lerp(a, b, t) {
    return a + (b - a) * t
}

// Map v in [edge0, edge1] to [0, 1] with clamping.
function remap(v, edge0, edge1) {
    if (edge1 <= edge0) return v >= edge1 ? 1 : 0
    return clamp((v - edge0) / (edge1 - edge0), 0, 1)
}

// Smoothstep C1 interpolation on [0, 1].
function smoothstep(t) {
    var x = clamp(t, 0, 1)
    return x * x * (3 - 2 * x)
}

// Viscous settle curve: fast initial movement -> long soft settle (approximates cubic-bezier(0.22, 1.0, 0.36, 1.0)).
function viscousOut(t) {
    var x = clamp(t, 0, 1)
    return 1 - Math.pow(1 - x, 3.4)
}

// Viscous settle with tiny authored overshoot (~2.8% max) for droplet pinch-off.
function viscousSettle(t, overshoot) {
    var x = clamp(t, 0, 1)
    var amp = overshoot !== undefined ? overshoot : 0.028
    var base = viscousOut(x)
    var bump = Math.sin(x * Math.PI) * Math.pow(1 - x, 1.6) * amp * 4.2
    return base + bump
}

// Controlled in-out pressure curve (InOutCubic).
function pressureInOut(t) {
    var x = clamp(t, 0, 1)
    return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2
}

// Suction curve for success merge: slow start -> accelerating inward pull -> clean stop.
function suctionInOut(t) {
    var x = clamp(t, 0, 1)
    if (x < 0.72) {
        var u = x / 0.72
        return 0.78 * (u * u * u)
    }
    var v = (x - 0.72) / 0.28
    return 0.78 + 0.22 * viscousOut(v)
}

// Evaluate quadratic Bezier point at t in [0, 1].
function quadPoint(p0x, p0y, cx, cy, p1x, p1y, t) {
    var u = 1 - t
    return {
        x: u * u * p0x + 2 * u * t * cx + t * t * p1x,
        y: u * u * p0y + 2 * u * t * cy + t * t * p1y
    }
}

// Evaluate liquid recoil wave on failureImpulse in [0, 1]:
// 0..0.20: compression (-1)
// 0.20..0.46: recoil overshoot (+1)
// 0.46..1.00: viscous reabsorption back to 0.
function recoilWave(failureImpulse) {
    var t = clamp(failureImpulse, 0, 1)
    if (t <= 0.0001 || t >= 0.9999) return { compress: 0, scatter: 0, overshoot: 0 }
    var compress = 0
    if (t < 0.14) {
        compress = Math.sin((t / 0.14) * (Math.PI / 2))
    } else if (t < 0.24) {
        compress = Math.cos(((t - 0.14) / 0.10) * (Math.PI / 2))
    }
    var scatter = 0
    if (t >= 0.14 && t < 0.44) {
        scatter = pressureInOut((t - 0.14) / 0.30)
    } else if (t >= 0.44) {
        scatter = 1 - viscousOut((t - 0.44) / 0.56)
    }
    var overshoot = 0
    if (t >= 0.24 && t < 0.52) {
        overshoot = Math.sin(((t - 0.24) / 0.28) * Math.PI)
    }
    return { compress: compress, scatter: scatter, overshoot: overshoot }
}

// Responsive layout metrics matching Concept 20 proportions across desktop, small, and portrait outputs.
function metrics(viewportWidth, viewportHeight, baseFontSize) {
    var vw = Math.max(320, Number(viewportWidth) || 1920)
    var vh = Math.max(240, Number(viewportHeight) || 1080)
    var fontScale = clamp((Number(baseFontSize) || 14) / 14, 0.75, 1.5)
    var minDim = Math.min(vw, vh)
    var compact = vw <= 650 || vh <= 650
    var maxOrbitByHeight = Math.max(220, vh - (compact ? 72 : 112))
    var orbitSize = compact
        ? Math.min(vw * 0.86, maxOrbitByHeight)
        : Math.min(760, vw * 0.82, maxOrbitByHeight)
    var scale = orbitSize / 760
    var ringThickness = compact
        ? Math.max(20, Math.round(30 * (orbitSize / 520)))
        : Math.max(28, Math.round(48 * scale))
    var coreWidth = orbitSize * (compact ? 0.84 : 0.76)
    var pillMaxWidth = Math.min(410, coreWidth)
    var pillHeight = compact ? Math.max(44, Math.round(52 * clamp(scale * 1.25, 0.8, 1))) : 58
    var submitSize = Math.max(34, pillHeight - 12)
    var clockSize = clamp(Math.round(Math.min(vw * 0.11, orbitSize * 0.174) * fontScale), compact ? 56 : 80, 140)
    return {
        viewportWidth: vw,
        viewportHeight: vh,
        compact: compact,
        orbitSize: orbitSize,
        scale: scale,
        ringThickness: ringThickness,
        coreWidth: coreWidth,
        pillMaxWidth: pillMaxWidth,
        pillHeight: pillHeight,
        submitSize: submitSize,
        clockPixelSize: clockSize,
        eyebrowPixelSize: Math.max(7, Math.round((compact ? 8 : 9) * fontScale))
    }
}

// Build one asymmetric pressure front with the same four cubic quadrants as the orbit.
function layerSealGeometry(m, state) {
    var s = state || {}
    var release = s.mode === "release"
    var progress = clamp(s.progress || 0, 0, 1)
    var cx = m.viewportWidth * 0.5
    var cy = m.viewportHeight * 0.5
    var maxRadius = Math.hypot(m.viewportWidth, m.viewportHeight) * 0.60 + m.ringThickness * 2
    var seedRadius = m.orbitSize * (release ? 0.08075 : 0.04)
    var travel = release ? pressureInOut(progress) : 1 - viscousOut(remap(progress, 0, 0.72))
    var compression = release ? 1 : 1 - 0.05 * Math.sin(remap(progress, 0.68, 1) * Math.PI)
    var radius = lerp(seedRadius * compression, maxRadius, travel)
    var stroke = release
        ? lerp(seedRadius * 2, m.ringThickness * 0.65, viscousOut(progress))
        : lerp(seedRadius * 2 * compression, m.ringThickness * 1.2, travel)
    var asym = release ? 0.04 * Math.sin(progress * Math.PI) : 0.045 * travel
    var rt = radius * (1 - asym)
    var rr = radius * (1 + asym * (release ? 1 : -0.8))
    var rb = radius * (1 + asym * 0.7)
    var rl = radius * (1 + asym * 1.1)
    var k = 0.55228475
    return {
        visible: !s.reducedMotion && (release ? progress > 0 : progress < 1),
        strokeWidth: stroke,
        top: { x: cx, y: cy - rt },
        right: { x: cx + rr, y: cy },
        bottom: { x: cx, y: cy + rb },
        left: { x: cx - rl, y: cy },
        c0a: { x: cx + rr * k, y: cy - rt },
        c0b: { x: cx + rr, y: cy - rt * k },
        c1a: { x: cx + rr, y: cy + rb * k },
        c1b: { x: cx + rr * k, y: cy + rb },
        c2a: { x: cx - rl * k, y: cy + rb },
        c2b: { x: cx - rl, y: cy + rb * k },
        c3a: { x: cx - rl, y: cy - rt * k },
        c3b: { x: cx - rl * k, y: cy - rt }
    }
}

// Compute the fixed-topology 4-quadrant cubic Bezier orbit ring and attached liquid protrusions.
// Transitions continuously across K0 Seed -> K1 Bloom -> K2 Orbit -> K3 Attached -> K4 Ready -> K5 Pressurized -> K6 Closed.
function orbitGeometry(m, state) {
    var s = state || {}
    var reduced = s.reducedMotion === true
    var entry = reduced ? 1 : clamp(s.entryProgress !== undefined ? s.entryProgress : 1, 0, 1)
    var idlePhase = reduced ? 0 : (Number(s.idlePhase) || 0)
    var focus = clamp(s.focusProgress || 0, 0, 1)
    var authPressure = clamp(s.authPressure || 0, 0, 1)
    var authLoop = Number(s.authLoopPhase) || 0
    var fail = recoilWave(s.failureImpulse || 0)
    var success = clamp(s.successProgress || 0, 0, 1)
    var suction = reduced ? smoothstep(success) : suctionInOut(success)

    var D = m.orbitSize
    var cx = D / 2
    var cy = D / 2
    var baseOuterR = D / 2

    // Bloom starts at 525ms after the capture front reaches the matching solid seed.
    var seedGrow = viscousOut(remap(entry, 0, 0.18))
    // Asymmetric extrusion: top-right stretches first, bottom-left follows slightly later.
    var extrudeTR = viscousOut(remap(entry, 0.10, 0.46))
    var extrudeBL = viscousOut(remap(entry, 0.15, 0.52))
    var extrudeMean = (extrudeTR + extrudeBL) * 0.5
    var holeOpen = viscousOut(remap(entry, 0.12, 0.48))
    var asymDevelop = viscousOut(remap(entry, 0.18, 0.68)) * (1 - suction)

    // Idle asymmetric 3-stage breathing (Ready A -> Ready B -> Ready C -> Ready A) preserving perceived mass.
    var idleAngle = idlePhase * Math.PI * 2
    var idleA = Math.sin(idleAngle)
    var idleB = Math.sin(idleAngle * 2 + 0.9)
    var idleScale = (1 - suction) * (1 - authPressure * 0.5) * smoothstep(remap(entry, 0.7, 1.0))
    var driftDiag1 = (idleA * 0.009 + idleB * 0.004) * D * idleScale
    var driftDiag2 = (-idleA * 0.008 + Math.cos(idleAngle + 0.6) * 0.004) * D * idleScale

    // Circulating pressure bulge during PAM wait (Phase 3F).
    var loopAngle = authLoop * Math.PI * 2
    var loopTop = Math.cos(loopAngle) * authPressure * D * 0.012 * (1 - suction)
    var loopRight = Math.sin(loopAngle) * authPressure * D * 0.012 * (1 - suction)
    var loopBottom = -Math.cos(loopAngle) * authPressure * D * 0.012 * (1 - suction)
    var loopLeft = -Math.sin(loopAngle) * authPressure * D * 0.012 * (1 - suction)

    // Focus & Auth & Failure local deformations (balanced to preserve ink volume).
    var bottomBulge = (focus * 0.018 - authPressure * 0.024 - fail.compress * 0.038 + fail.scatter * 0.016) * D * (1 - suction)
    var sideCompensation = (-focus * 0.008 + authPressure * 0.012 - fail.compress * 0.022 + fail.scatter * 0.032) * D * (1 - suction)
    var topCompensation = (-focus * 0.005 + authPressure * 0.008 + fail.compress * 0.012 - fail.scatter * 0.018) * D * (1 - suction)

    // Outer and inner radius progression (K0 solid nucleus -> K4 thick ring -> K6 compact closed ring/iris).
    var seedRadius = baseOuterR * lerp(0.16, 0.24, seedGrow)
    var readyOuterR = baseOuterR
    var compression = remap(success, 0.88, 1)
    var closedOuterR = baseOuterR * 0.34 * (1 - 0.10 * Math.sin(compression * Math.PI) - 0.05 * smoothstep(compression))
    var currentOuterR = lerp(lerp(seedRadius, readyOuterR, extrudeMean), closedOuterR, suction)

    var readyRingW = m.ringThickness + Math.sin(idleAngle + 0.4) * 1.2 * idleScale + authPressure * 2.5
    var closedRingW = closedOuterR
    var fullRingW = lerp(readyRingW, closedRingW, suction)
    var strokeW = lerp(currentOuterR, fullRingW, holeOpen * (1 - smoothstep(remap(success, 0.56, 0.96))))
    var midR = Math.max(strokeW * 0.5, currentOuterR - strokeW * 0.5)

    // Directional outer-to-mid radius per cardinal side so TR stretches before BL during LockIn.
    var outerTR = lerp(lerp(seedRadius, readyOuterR, extrudeTR), closedOuterR, suction)
    var outerBL = lerp(lerp(seedRadius, readyOuterR, extrudeBL), closedOuterR, suction)
    var midTR = Math.max(strokeW * 0.5, outerTR - strokeW * 0.5)
    var midBL = Math.max(strokeW * 0.5, outerBL - strokeW * 0.5)

    var rTop = midTR * (1 + 0.015 * asymDevelop) + driftDiag2 + topCompensation + loopTop
    var rRight = midTR * (1 - 0.022 * asymDevelop) + driftDiag1 + sideCompensation + loopRight
    var rBottom = midBL * (1 + 0.012 * asymDevelop) - driftDiag2 + bottomBulge + loopBottom
    var rLeft = midBL * (1 + 0.024 * asymDevelop) - driftDiag1 + sideCompensation + loopLeft

    // Concept 20 border-radius: 48% 52% 44% 56% / 56% 43% 57% 44%
    // Asymmetric cardinal tangent offsets and handle lengths:
    var topShiftX = -0.022 * D * asymDevelop
    var bottomShiftX = 0.032 * D * asymDevelop
    var leftShiftY = 0.028 * D * asymDevelop
    var rightShiftY = -0.034 * D * asymDevelop

    var topX = cx + topShiftX
    var topY = cy - rTop
    var rightX = cx + rRight
    var rightY = cy + rightShiftY
    var bottomX = cx + bottomShiftX
    var bottomY = cy + rBottom
    var leftX = cx - rLeft
    var leftY = cy + leftShiftY

    var k = 0.55228475
    // Quadrant handle weights tuned to 48/52/44/56 horizontal and 56/43/57/44 vertical curvature:
    var kTR_x = k * lerp(1.0, 1.08, asymDevelop)
    var kTR_y = k * lerp(1.0, 0.88, asymDevelop)
    var kBR_x = k * lerp(1.0, 0.90, asymDevelop)
    var kBR_y = k * lerp(1.0, 1.12, asymDevelop)
    var kBL_x = k * lerp(1.0, 1.12, asymDevelop)
    var kBL_y = k * lerp(1.0, 0.90, asymDevelop)
    var kTL_x = k * lerp(1.0, 0.96, asymDevelop)
    var kTL_y = k * lerp(1.0, 1.10, asymDevelop)

    // Attached protrusions (K3 Attached: T=180..480ms, entry 0.24..0.72, retracting on Success).
    var attachT = (reduced ? 1 : viscousSettle(remap(entry, 0.24, 0.72), 0.022)) * (1 - suction)
    var lobeScale = smoothstep(remap(entry, 0.14, 0.28)) * (1 - smoothstep(remap(suction, 0.75, 1)))
    var beforeW = lerp(strokeW * 0.75, (m.compact ? 78 : 130) * (m.compact ? m.orbitSize / 520 : m.scale), attachT)
        + driftDiag1 * 0.35
    var beforeH = lerp(strokeW * 0.75, (m.compact ? 52 : 78) * (m.compact ? m.orbitSize / 520 : m.scale), attachT)
        - driftDiag1 * 0.2
    var beforeRestCenterX = D + (m.compact ? 66 * (m.orbitSize / 520) : 94 * m.scale) - beforeW * 0.5
    var beforeRestCenterY = D * 0.17 + beforeH * 0.5
    var beforeSubmergedX = cx + rRight * 0.78
    var beforeSubmergedY = cy - rTop * 0.58
    var beforeCenterX = lerp(beforeSubmergedX, beforeRestCenterX, attachT) - authPressure * 3 * m.scale
    var beforeCenterY = lerp(beforeSubmergedY, beforeRestCenterY, attachT) + idleA * 2.5 * idleScale
    var beforeRotation = lerp(0, -18, attachT) + idleB * 1.4 * idleScale

    var afterSize = lerp(strokeW * 0.75, (m.compact ? 58 : 86) * (m.compact ? m.orbitSize / 520 : m.scale), attachT)
        - driftDiag1 * 0.3
    var afterRestCenterX = -(m.compact ? 50 * (m.orbitSize / 520) : 72 * m.scale) + afterSize * 0.5
    var afterRestCenterY = D * (1 - 0.15) - afterSize * 0.5
    var afterSubmergedX = cx - rLeft * 0.78
    var afterSubmergedY = cy + rBottom * 0.56
    var afterCenterX = lerp(afterSubmergedX, afterRestCenterX, attachT) + authPressure * 3 * m.scale
    var afterCenterY = lerp(afterSubmergedY, afterRestCenterY, attachT) - idleA * 2.5 * idleScale

    return {
        strokeWidth: strokeW,
        top: { x: topX, y: topY },
        right: { x: rightX, y: rightY },
        bottom: { x: bottomX, y: bottomY },
        left: { x: leftX, y: leftY },
        // Top -> Right
        c0a: { x: topX + (rightX - topX) * kTR_x, y: topY },
        c0b: { x: rightX, y: rightY - (rightY - topY) * kTR_y },
        // Right -> Bottom
        c1a: { x: rightX, y: rightY + (bottomY - rightY) * kBR_y },
        c1b: { x: bottomX + (rightX - bottomX) * kBR_x, y: bottomY },
        // Bottom -> Left
        c2a: { x: bottomX - (bottomX - leftX) * kBL_x, y: bottomY },
        c2b: { x: leftX, y: leftY + (bottomY - leftY) * kBL_y },
        // Left -> Top
        c3a: { x: leftX, y: leftY - (leftY - topY) * kTL_y },
        c3b: { x: topX - (topX - leftX) * kTL_x, y: topY },
        beforeBlob: {
            x: beforeCenterX - beforeW * lobeScale * 0.5,
            y: beforeCenterY - beforeH * lobeScale * 0.5,
            width: beforeW * lobeScale,
            height: beforeH * lobeScale,
            radius: beforeH * lobeScale * 0.5,
            rotation: beforeRotation,
            visible: lobeScale > 0.001
        },
        afterBlob: {
            x: afterCenterX - afterSize * lobeScale * 0.5,
            y: afterCenterY - afterSize * lobeScale * 0.5,
            width: afterSize * lobeScale,
            height: afterSize * lobeScale,
            radius: afterSize * lobeScale * 0.5,
            visible: lobeScale > 0.001
        }
    }
}

// Compute the 3 satellite droplets (n1, n2, n3) originating from the ring, drifting in idle,
// circulating during auth, scattering/reabsorbing on failure, and merging into the ring on success.
function dropletsGeometry(m, orbit, state) {
    var s = state || {}
    var reduced = s.reducedMotion === true
    var entry = reduced ? 1 : clamp(s.entryProgress !== undefined ? s.entryProgress : 1, 0, 1)
    var idlePhase = reduced ? 0 : (Number(s.idlePhase) || 0)
    var authPressure = clamp(s.authPressure || 0, 0, 1)
    var authLoop = Number(s.authLoopPhase) || 0
    var fail = recoilWave(s.failureImpulse || 0)
    var success = clamp(s.successProgress || 0, 0, 1)
    var suction = reduced ? smoothstep(success) : suctionInOut(success)

    var D = m.orbitSize
    var cx = D / 2
    var cy = D / 2
    var kScale = m.compact ? (m.orbitSize / 520) * 0.72 : m.scale

    var specs = [
        // n1: bottom-right droplet (42px at 760 scale, right: 7%, bottom: -68px)
        {
            size: Math.max(14, 42 * kScale),
            originX: cx + (orbit.right.x - cx) * 0.58,
            originY: cy + (orbit.bottom.y - cy) * 0.86,
            ctrlX: D * 0.88,
            ctrlY: D * 0.98,
            restX: D * 0.93 - 21 * kScale,
            restY: D + (m.compact ? 26 : 68) * kScale - 21 * kScale,
            entryStart: 0.22,
            entryEnd: 0.56,
            phaseOffset: 0.0,
            driftX: 8 * kScale,
            driftY: 6 * kScale,
            scatterDX: 10 * kScale,
            scatterDY: 12 * kScale,
            circulateAmp: 22 * kScale
        },
        // n2: lower-right smaller droplet (22px at 760 scale, right: -82px, bottom: 9%)
        {
            size: Math.max(10, 22 * kScale),
            originX: cx + (orbit.right.x - cx) * 0.88,
            originY: cy + (orbit.bottom.y - cy) * 0.52,
            ctrlX: D * 1.02,
            ctrlY: D * 0.76,
            restX: D + (m.compact ? 32 : 82) * kScale - 11 * kScale,
            restY: D * 0.91 - 11 * kScale,
            entryStart: 0.26,
            entryEnd: 0.60,
            phaseOffset: 2.1,
            driftX: 6 * kScale,
            driftY: 9 * kScale,
            scatterDX: 14 * kScale,
            scatterDY: 8 * kScale,
            circulateAmp: 30 * kScale
        },
        // n3: top-left larger droplet (64px at 760 scale, left: 9%, top: -82px)
        {
            size: Math.max(20, 64 * kScale),
            originX: cx - (cx - orbit.left.x) * 0.62,
            originY: cy - (cy - orbit.top.y) * 0.86,
            ctrlX: D * 0.14,
            ctrlY: D * 0.02,
            restX: D * 0.09 + 32 * kScale,
            restY: -(m.compact ? 28 : 82) * kScale + 32 * kScale,
            entryStart: 0.20,
            entryEnd: 0.54,
            phaseOffset: 4.2,
            driftX: 10 * kScale,
            driftY: 7 * kScale,
            scatterDX: -12 * kScale,
            scatterDY: -11 * kScale,
            circulateAmp: 16 * kScale
        }
    ]

    var idleWeight = (1 - suction) * smoothstep(remap(entry, 0.55, 1.0))
    var orbitBoxLeft = (m.viewportWidth - D) * 0.5
    var orbitBoxTop = (m.viewportHeight - D) * 0.5
    var out = []

    for (var i = 0; i < specs.length; i++) {
        var sp = specs[i]
        var detachT = reduced ? 1 : viscousSettle(remap(entry, sp.entryStart, sp.entryEnd), 0.032)
        var basePt = quadPoint(sp.originX, sp.originY, sp.ctrlX, sp.ctrlY, sp.restX, sp.restY, detachT)

        // Idle slow viscous orbital path (Phase 3C: 4-14px translation, 0.92-1.08 scale).
        var a = idlePhase * Math.PI * 2 + sp.phaseOffset
        var dxIdle = (Math.sin(a) * sp.driftX + Math.cos(a * 2) * sp.driftX * 0.25) * idleWeight
        var dyIdle = (Math.cos(a + 0.4) * sp.driftY) * idleWeight
        var scaleIdle = 1 + Math.sin(a + 1.1) * 0.06 * idleWeight

        // Auth circulation along local curved tangent (Phase 3F).
        var authArc = authPressure * (1 - suction)
        var loopA = authLoop * Math.PI * 2 + sp.phaseOffset
        var dxAuth = Math.cos(loopA) * sp.circulateAmp * authArc
        var dyAuth = Math.sin(loopA) * sp.circulateAmp * 0.65 * authArc

        // Failure recoil scatter & curved reabsorption (Phase 3G).
        var dxFail = fail.scatter * sp.scatterDX - fail.compress * sp.scatterDX * 0.25
        var dyFail = fail.scatter * sp.scatterDY - fail.compress * sp.scatterDY * 0.25

        var posX = basePt.x + dxIdle + dxAuth + dxFail
        var posY = basePt.y + dyIdle + dyAuth + dyFail

        // Success suction inward back into the ring mass (Phase 3H).
        var mergeTargetX = cx
        var mergeTargetY = cy
        var mergeCtrlX = (posX + cx) * 0.5 + (posY - cy) * 0.18
        var mergeCtrlY = (posY + cy) * 0.5 - (posX - cx) * 0.18
        var finalPt = quadPoint(posX, posY, mergeCtrlX, mergeCtrlY, mergeTargetX, mergeTargetY, suction)

        var seedScale = viscousOut(remap(entry, sp.entryStart, sp.entryEnd))
        var mergeScale = 1 - smoothstep(remap(suction, 0.85, 1))
        var dSize = sp.size * seedScale * scaleIdle * mergeScale
        var r = dSize * 0.5

        // Clamp within safe viewport bounds so droplets never clip on tight aspect ratios.
        var minLocalX = -orbitBoxLeft + r + 8
        var maxLocalX = m.viewportWidth - orbitBoxLeft - r - 8
        var minLocalY = -orbitBoxTop + r + 8
        var maxLocalY = m.viewportHeight - orbitBoxTop - r - 8
        var clampedX = clamp(finalPt.x, minLocalX, maxLocalX)
        var clampedY = clamp(finalPt.y, minLocalY, maxLocalY)

        out.push({
            x: clampedX - r,
            y: clampedY - r,
            centerX: clampedX,
            centerY: clampedY,
            width: dSize,
            height: dSize,
            radius: r,
            visible: dSize > 0.01
        })
    }
    return out
}

// Compute the auth capsule, submit circle, and typography settle geometry.
// Phase 3B (extrusion from small round blob), 3D (focus pressure), 3E (keystroke impulse),
// 3F (submit compression), 3G (failure recoil), 3H (success swell & merge into core).
function authPillGeometry(m, state) {
    var s = state || {}
    var reduced = s.reducedMotion === true
    var entry = reduced ? 1 : clamp(s.entryProgress !== undefined ? s.entryProgress : 1, 0, 1)
    var idlePhase = reduced ? 0 : (Number(s.idlePhase) || 0)
    var focus = clamp(s.focusProgress || 0, 0, 1)
    var authPressure = clamp(s.authPressure || 0, 0, 1)
    var keystroke = clamp(s.keystrokeImpulse || 0, 0, 1)
    var fail = recoilWave(s.failureImpulse || 0)
    var success = clamp(s.successProgress || 0, 0, 1)

    // Grow the auth seed into a horizontal capsule during bloom.
    var seedAppear = reduced ? 1 : viscousOut(remap(entry, 0.26, 0.44))
    var pillExtrude = reduced ? 1 : viscousSettle(remap(entry, 0.26, 0.80), 0.018)

    var baseW = m.pillMaxWidth
    var baseH = m.pillHeight

    // Idle 1-2px breathing only when not actively typing; focus adds +2.5% internal pressure.
    var idleBreath = (1 - focus) * Math.sin(idlePhase * Math.PI * 2) * 1.5 * smoothstep(remap(entry, 0.8, 1.0))
    var focusFactor = 1 + focus * 0.025
    // Submit compresses by 4%; failure contracts to 92% then overshoots by 2%; keystroke adds 1.5px impulse.
    var pressureFactor = 1
        - authPressure * 0.04
        - fail.compress * 0.08
        + fail.overshoot * 0.02
    var keystrokeW = keystroke * 1.6
    var keystrokeH = keystroke * 0.8

    var extrudedW = lerp(baseH, baseW, pillExtrude) * focusFactor * pressureFactor + idleBreath + keystrokeW
    var extrudedH = baseH + focus * 1.0 - authPressure * 1.2 - fail.compress * 1.5 + keystrokeH

    // Phase 3H Success: 0..0.28 swell slightly (+3%), 0.22..0.85 contract into compact circular liquid core.
    var swell = success > 0 && success < 0.32 ? Math.sin((success / 0.32) * Math.PI) * 0.032 : 0
    var coreMerge = reduced ? smoothstep(success) : suctionInOut(remap(success, 0.16, 0.88))
    var finalW = lerp(extrudedW * (1 + swell), baseH * 1.08, coreMerge)
    var finalH = lerp(extrudedH * (1 + swell * 0.5), baseH * 1.08, coreMerge)

    // Submit circle separates during extrusion, pulls 2-4px inward on focus/submit, pushes away on fail compress,
    // and merges into the pill center on success.
    var submitSeparate = reduced ? 1 : viscousOut(remap(entry, 0.48, 0.82))
    var restPadRight = 6
    var focusPull = focus * 2.5 + authPressure * 3.5 - fail.compress * 3.5
    var maxRightOffset = Math.max(0, (finalW - m.submitSize) * 0.5 - restPadRight - focusPull)
    var submitOffsetFromCenter = maxRightOffset * submitSeparate * (1 - coreMerge)
    var submitScale = submitSeparate * lerp(1.0, 0.0, remap(coreMerge, 0.35, 0.92))

    // Reveal typography locally as bloom settles; clock scale moves from 0.98 to 1.00.
    var contentReveal = reduced ? 1 : viscousOut(remap(entry, 0.43, 0.94))
    var contentExit = 1 - smoothstep(remap(success, 0.08, 0.58))
    var clockScale = lerp(0.98, 1.0, contentReveal) * lerp(1.0, 0.92, smoothstep(remap(success, 0.1, 0.7)))

    return {
        width: Math.max(finalH, finalW),
        height: Math.max(24, finalH),
        radius: Math.max(12, finalH * 0.5),
        scale: seedAppear * (1 - smoothstep(remap(success, 0.88, 1))),
        mergeProgress: coreMerge,
        offsetY: lerp(0, -m.orbitSize * 0.09, coreMerge),
        submitSize: m.submitSize,
        submitX: (Math.max(finalH, finalW) * 0.5) + submitOffsetFromCenter - m.submitSize * 0.5,
        submitY: (Math.max(24, finalH) - m.submitSize) * 0.5,
        submitScale: submitScale,
        submitVisible: submitScale > 0.001,
        inputOpacity: clamp(remap(pillExtrude, 0.25, 0.75) * (1 - remap(success, 0.0, 0.25)), 0, 1),
        contentOpacity: clamp(contentReveal * contentExit, 0, 1),
        clockScale: clockScale,
        visible: seedAppear > 0.001 && success < 1
    }
}
