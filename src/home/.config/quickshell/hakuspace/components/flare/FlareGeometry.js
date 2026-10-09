.pragma library


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

function durations(movingTowardStart, D, trailFactor) {
    var baseD = Number(D) || 0;
    var tf = Number(trailFactor) || 1;
    return {
        startMs: movingTowardStart ? baseD : baseD * tf,
        endMs: movingTowardStart ? baseD * tf : baseD
    };
}

function needsRetarget(prev, next, eps) {
    var e = Number(eps) || 2;
    var pStart = (prev && Number(prev.start)) || 0;
    var pEnd = (prev && Number(prev.end)) || 0;
    var nStart = (next && Number(next.start)) || 0;
    var nEnd = (next && Number(next.end)) || 0;
    
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
