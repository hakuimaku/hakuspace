.pragma library

function clamp(val, min, max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
}

// Applies temporal smoothing (fast attack, slower liquid release).
// currentBars and targetBars are arrays of floats [0..1].
function applyTemporalSmoothing(currentBars, targetBars, attackRate, releaseRate, gamma) {
    if (!targetBars || targetBars.length === 0) return currentBars || [];
    var count = targetBars.length;
    var result = new Array(count);
    var attack = (attackRate !== undefined && attackRate > 0) ? attackRate : 0.45;
    var release = (releaseRate !== undefined && releaseRate > 0) ? releaseRate : 0.20;
    var g = (gamma !== undefined && gamma > 0) ? gamma : 0.85;

    for (var i = 0; i < count; ++i) {
        var curr = (currentBars && i < currentBars.length) ? currentBars[i] : 0.0;
        var rawTarget = targetBars[i];
        var target = (g === 1.0) ? rawTarget : Math.pow(rawTarget, g);

        if (target > curr) {
            curr = curr + (target - curr) * attack;
        } else {
            curr = curr + (target - curr) * release;
        }

        if (curr < 0.001) curr = 0.0;
        else if (curr > 1.0) curr = 1.0;

        result[i] = curr;
    }

    return result;
}

// 3-point weighted spatial smoothing across adjacent bars.
function applySpatialSmoothing(bars, strength) {
    if (!bars || bars.length <= 1) return bars || [];
    var count = bars.length;
    var result = new Array(count);
    var s = (strength !== undefined) ? clamp(strength, 0.0, 1.0) : 0.5;

    var sideWeight = 0.20 * s;
    var centerWeight = 1.0 - (2.0 * sideWeight);

    // Left edge
    result[0] = bars[0] * (1.0 - sideWeight) + bars[1] * sideWeight;

    // Interior bars
    for (var i = 1; i < count - 1; ++i) {
        result[i] = bars[i - 1] * sideWeight + bars[i] * centerWeight + bars[i + 1] * sideWeight;
    }

    // Right edge
    result[count - 1] = bars[count - 2] * sideWeight + bars[count - 1] * (1.0 - sideWeight);

    return result;
}

// Derives semantic audio energy values from spectrum bars.
// For stereo CAVA layout (low frequencies in center, high on outer edges).
function computeEnergies(bars) {
    if (!bars || bars.length === 0) {
        return { overall: 0.0, bass: 0.0, mid: 0.0, treble: 0.0, peak: 0.0 };
    }

    var count = bars.length;
    var sum = 0.0;
    var peak = 0.0;

    var bassStart = Math.floor(count * 0.35);
    var bassEnd = Math.ceil(count * 0.65);
    var midLeftStart = Math.floor(count * 0.15);
    var midRightEnd = Math.ceil(count * 0.85);

    var bassSum = 0.0;
    var bassCount = 0;
    var midSum = 0.0;
    var midCount = 0;
    var trebleSum = 0.0;
    var trebleCount = 0;

    for (var i = 0; i < count; ++i) {
        var v = bars[i];
        sum += v;
        if (v > peak) peak = v;

        if (i >= bassStart && i < bassEnd) {
            bassSum += v;
            bassCount++;
        } else if ((i >= midLeftStart && i < bassStart) || (i >= bassEnd && i < midRightEnd)) {
            midSum += v;
            midCount++;
        } else {
            trebleSum += v;
            trebleCount++;
        }
    }

    return {
        overall: sum / count,
        bass: bassCount > 0 ? (bassSum / bassCount) : 0.0,
        mid: midCount > 0 ? (midSum / midCount) : 0.0,
        treble: trebleCount > 0 ? (trebleSum / trebleCount) : 0.0,
        peak: peak
    };
}
