.pragma library

function createParser(options) {
    var buffer = "";
    var barCount = (options && options.barCount) ? options.barCount : 64;
    var maxRange = (options && options.maxRange) ? options.maxRange : 1000;
    var malformedFrames = 0;
    var totalFrames = 0;

    function parseTokens(line) {
        if (!line) return null;
        var rawTokens = line.trim().split(";");
        var frameVals = [];

        for (var i = 0; i < rawTokens.length; ++i) {
            var token = rawTokens[i].trim();
            if (token.length === 0) continue;
            var num = parseInt(token, 10);
            if (isNaN(num)) return null;
            if (num < 0) num = 0;
            else if (num > maxRange) num = maxRange;
            frameVals.push(num / maxRange);
        }

        if (frameVals.length === 0) return null;

        if (frameVals.length < barCount) {
            while (frameVals.length < barCount) {
                frameVals.push(0.0);
            }
        } else if (frameVals.length > barCount) {
            var binned = new Array(barCount);
            var step = frameVals.length / barCount;
            for (var b = 0; b < barCount; ++b) {
                var startIdx = Math.floor(b * step);
                var endIdx = Math.floor((b + 1) * step);
                var maxVal = 0.0;
                for (var k = startIdx; k < endIdx; ++k) {
                    if (frameVals[k] > maxVal) maxVal = frameVals[k];
                }
                binned[b] = maxVal;
            }
            frameVals = binned;
        }

        return frameVals;
    }

    return {
        setBarCount: function(count) {
            if (count > 0) barCount = count;
        },
        reset: function() {
            buffer = "";
            malformedFrames = 0;
            totalFrames = 0;
        },
        getMalformedCount: function() {
            return malformedFrames;
        },
        getTotalFrameCount: function() {
            return totalFrames;
        },
        // Feed a single pre-split line (e.g. from SplitParser)
        feedLine: function(line) {
            if (!line || line.trim().length === 0) return null;
            var parsed = parseTokens(line);
            if (!parsed) {
                malformedFrames++;
                return null;
            }
            totalFrames++;
            return parsed;
        },
        // Feed arbitrary chunk stream
        feed: function(chunk) {
            if (!chunk) return null;
            buffer += chunk;

            var newlineIdx;
            var latestFrame = null;

            while ((newlineIdx = buffer.indexOf("\n")) !== -1) {
                var line = buffer.substring(0, newlineIdx).trim();
                buffer = buffer.substring(newlineIdx + 1);

                if (line.length === 0) continue;

                var parsed = parseTokens(line);
                if (!parsed) {
                    malformedFrames++;
                    continue;
                }

                totalFrames++;
                latestFrame = parsed;
            }

            return latestFrame;
        }
    };
}
