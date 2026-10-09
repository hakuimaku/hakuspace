.pragma library

/**
 * @file FlareGeometry.js
 * @brief Geometry calculations for Flare Lib surfaces and morphing tooltips.
 * 
 * Note: `.pragma library` is a standard Qt QML directive that enables
 * this JavaScript file to be loaded as a shared library across QML components.
 * Linters configured for pure Node.js/browser JS may flag it, but it is 100% valid in QML.
 */

/**
 * Calculates horizontal span bounds [start, end] for a tooltip / popup target.
 *
 * @param {Object} args - Input parameters for span resolution
 * @param {number} [args.anchorStart=0] - Left X coordinate of anchor item
 * @param {number} [args.anchorEnd=0] - Right X coordinate of anchor item
 * @param {number} [args.contentW=0] - Content width requirement
 * @param {number} [args.padX=0] - Horizontal padding
 * @param {number} [args.minW=0] - Minimum span width
 * @param {number} [args.maxW=Infinity] - Maximum span width
 * @param {Object} [args.bounds] - Screen/bar boundary { start: number, end: number }
 * @param {number} [args.snap=0] - Boundary snap threshold
 * @returns {{ start: number, end: number }} Resolved span coordinates
 */
function resolveSpan(args) {
    if (!args) return { start: 0, end: 0 };
    
    var anchorStart = Number(args.anchorStart) || 0;
    var anchorEnd = Number(args.anchorEnd) || 0;
    var contentW = Number(args.contentW) || 0;
    var padX = Number(args.padX) || 0;
    var minW = Number(args.minW) || 0;
    var maxW = Number(args.maxW) || Infinity;
    var bStart = (args.bounds && Number(args.bounds.start)) || 0;
    var bEnd = (args.bounds && Number(args.bounds.end)) || 0;
    var snap = Number(args.snap) || 0;

    var reqW = contentW + padX;
    reqW = Math.max(minW, Math.min(reqW, maxW));
    
    var center = anchorStart + (anchorEnd - anchorStart) / 2;
    var eL = center - reqW / 2;
    var eR = center + reqW / 2;

    if (eL < bStart + snap) {
        eL = bStart;
        eR = Math.max(eR, eL + reqW);
    } else if (eR > bEnd - snap) {
        eR = bEnd;
        eL = Math.min(eL, eR - reqW);
    }

    eL = Math.max(bStart, Math.min(eL, bEnd));
    eR = Math.max(bStart, Math.min(eR, bEnd));
    
    if (eR - eL > maxW) {
        eR = eL + maxW;
        if (eR > bEnd) {
            eR = bEnd;
            eL = Math.max(bStart, eR - maxW);
        }
    }

    return { start: eL, end: eR };
}

/**
 * Computes edge proximity factors (kS, kE) in range [0, 1] relative to bounds.
 *
 * @param {number} start - Current span start coordinate
 * @param {number} end - Current span end coordinate
 * @param {Object} config - Configuration object
 * @param {Object} [config.bounds] - Screen/bar bounds { start: number, end: number }
 * @param {number} [config.rf=1] - Foot transition radius
 * @returns {{ kS: number, kE: number }} Edge factors (0 at boundary, 1 when far)
 */
function hugFactors(start, end, config) {
    var bStart = (config && config.bounds && Number(config.bounds.start)) || 0;
    var bEnd = (config && config.bounds && Number(config.bounds.end)) || 0;
    var rf = (config && Number(config.rf)) || 1;
    if (rf === 0) rf = 1;

    var kS = (start - bStart) / rf;
    var kE = (bEnd - end) / rf;

    return {
        kS: Math.max(0, Math.min(1, kS)) || 0,
        kE: Math.max(0, Math.min(1, kE)) || 0
    };
}

/**
 * Calculates geometry positions and scales for corner ears and feet.
 *
 * @param {Object} state - Current surface state { start, end, height, kS, kE }
 * @param {Object} config - Surface configuration { r, rf }
 * @returns {Object} Calculated positions and scaling factors for ears and feet
 */
function pieces(state, config) {
    if (!state) state = {};
    if (!config) config = {};
    
    var start = Number(state.start) || 0;
    var end = Number(state.end) || 0;
    var height = Number(state.height) || 0;
    var kS = Number(state.kS) || 0;
    var kE = Number(state.kE) || 0;
    
    var r = Number(config.r) || 0;
    var rf = Number(config.rf) || 0;

    var earScaleS = kS * (r > 0 ? Math.min(1, height / r) : 0);
    var earScaleE = kE * (r > 0 ? Math.min(1, height / r) : 0);
    var footScaleS = (1 - kS) * (rf > 0 ? Math.min(1, height / rf) : 0);
    var footScaleE = (1 - kE) * (rf > 0 ? Math.min(1, height / rf) : 0);

    return {
        earStart: { u: start - r, v: 0, scale: Math.max(0, earScaleS) || 0 },
        earEnd: { u: end, v: 0, scale: Math.max(0, earScaleE) || 0 },
        footStart: { u: start, v: height, scale: Math.max(0, footScaleS) || 0 },
        footEnd: { u: end - rf, v: height, scale: Math.max(0, footScaleE) || 0 },
        radiusStart: Math.max(0, r * kS) || 0,
        radiusEnd: Math.max(0, r * kE) || 0
    };
}

/**
 * Determines animation durations for asymmetric leading/trailing morph transitions.
 *
 * @param {boolean} movingTowardStart - Direction of movement
 * @param {number} D - Base duration in milliseconds
 * @param {number} trailFactor - Factor for trailing edge speed adjustment
 * @returns {{ startMs: number, endMs: number }} Animation duration object
 */
function durations(movingTowardStart, D, trailFactor) {
    var baseD = Number(D) || 0;
    var tf = Number(trailFactor) || 1;
    return {
        startMs: movingTowardStart ? baseD : baseD * tf,
        endMs: movingTowardStart ? baseD * tf : baseD
    };
}

/**
 * Checks if target position change exceeds threshold to justify retargeting animation.
 *
 * @param {Object} prev - Previous span { start, end }
 * @param {Object} next - Next target span { start, end }
 * @param {number} [eps=2] - Epsilon threshold in pixels
 * @returns {boolean} True if retargeting is needed
 */
function needsRetarget(prev, next, eps) {
    var e = Number(eps) || 2;
    var pStart = (prev && Number(prev.start)) || 0;
    var pEnd = (prev && Number(prev.end)) || 0;
    var nStart = (next && Number(next.start)) || 0;
    var nEnd = (next && Number(next.end)) || 0;
    
    return Math.abs(pStart - nStart) > e || Math.abs(pEnd - nEnd) > e;
}

// Node.js module export support for automated unit testing (test_flare_geometry.js)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        resolveSpan: resolveSpan,
        hugFactors: hugFactors,
        pieces: pieces,
        durations: durations,
        needsRetarget: needsRetarget
    };
}
