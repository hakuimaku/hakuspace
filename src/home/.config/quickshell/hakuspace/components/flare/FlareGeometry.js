.pragma library

function finite(value, fallback) {
    if (value === null || value === undefined || value === "") return fallback;
    var n = Number(value);
    return isFinite(n) ? n : fallback;
}

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value));
}

function resolveSpan(args) {
    if (!args) return { start: 0, end: 0 };
    var anchorStart = finite(args.anchorStart, 0);
    var anchorEnd = finite(args.anchorEnd, anchorStart);
    var contentW = Math.max(0, finite(args.contentW, 0));
    var padX = Math.max(0, finite(args.padX, 0));
    var minW = Math.max(0, finite(args.minW, 0));
    var bStart = finite(args.bounds && args.bounds.start, 0);
    var bEnd = finite(args.bounds && args.bounds.end, bStart);
    if (bEnd <= bStart) return { start: bStart, end: bStart };
    var available = bEnd - bStart;
    var maxW = Math.max(0, finite(args.maxW, available));
    var snap = Math.max(0, finite(args.snap, 0));

    var reqW = clamp(contentW + padX, Math.min(minW, maxW), maxW);
    reqW = Math.min(reqW, available);
    
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

    eL = clamp(eL, bStart, bEnd - reqW);
    eR = clamp(eR, eL + reqW, bEnd);
    if (eR - eL > maxW) eR = eL + maxW;

    return { start: eL, end: eR };
}

function hugFactors(start, end, config) {
    var bStart = finite(config && config.bounds && config.bounds.start, 0);
    var bEnd = finite(config && config.bounds && config.bounds.end, bStart);
    var rf = Math.max(0, finite(config && config.rf, 0));
    var gapS = finite(start, bStart) - bStart;
    var gapE = bEnd - finite(end, bEnd);
    var kS = rf > 0 ? gapS / rf : (gapS > 0 ? 1 : 0);
    var kE = rf > 0 ? gapE / rf : (gapE > 0 ? 1 : 0);

    return {
        kS: clamp(kS, 0, 1),
        kE: clamp(kE, 0, 1)
    };
}

function pieces(state, config) {
    if (!state) state = {};
    if (!config) config = {};
    
    var start = finite(state.start, 0);
    var end = finite(state.end, start);
    var height = Math.max(0, finite(state.height, 0));
    var kS = clamp(finite(state.kS, 0), 0, 1);
    var kE = clamp(finite(state.kE, 0), 0, 1);

    var r = Math.max(0, finite(config.r, 0));
    var rf = Math.max(0, finite(config.rf, 0));

    var earScaleS = kS * (r > 0 ? Math.min(1, height / r) : 0);
    var earScaleE = kE * (r > 0 ? Math.min(1, height / r) : 0);
    var footScaleS = (1 - kS) * (rf > 0 ? Math.min(1, height / rf) : 0);
    var footScaleE = (1 - kE) * (rf > 0 ? Math.min(1, height / rf) : 0);

    return {
        earStart: { u: start - r, v: 0, scale: earScaleS },
        earEnd: { u: end, v: 0, scale: earScaleE },
        footStart: { u: start, v: height, scale: footScaleS },
        footEnd: { u: end - rf, v: height, scale: footScaleE },
        radiusStart: r * kS,
        radiusEnd: r * kE
    };
}

function durations(movingTowardStart, D, trailFactor) {
    var baseD = Math.max(0, finite(D, 0));
    var tf = Math.max(0, finite(trailFactor, 1));
    return {
        startMs: movingTowardStart ? baseD : baseD * tf,
        endMs: movingTowardStart ? baseD * tf : baseD
    };
}

function needsRetarget(prev, next, eps) {
    var e = Math.max(0, finite(eps, 2));
    var pStart = finite(prev && prev.start, 0);
    var pEnd = finite(prev && prev.end, 0);
    var nStart = finite(next && next.start, 0);
    var nEnd = finite(next && next.end, 0);
    
    return Math.abs(pStart - nStart) > e || Math.abs(pEnd - nEnd) > e;
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        resolveSpan: resolveSpan,
        hugFactors: hugFactors,
        pieces: pieces,
        durations: durations,
        needsRetarget: needsRetarget
    };
}
