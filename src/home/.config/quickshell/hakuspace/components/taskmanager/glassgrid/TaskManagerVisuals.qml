import QtQuick
import "../../../services"
import "../TaskManagerLogic.js" as Logic

QtObject {
    id: root

    // Reserve readable telemetry space beside the process table.
    function leftPaneWidth(totalWidth) {
        var w = Math.max(0, totalWidth || 0)
        if (w < 740) return 268
        if (w < 840) return 288
        return Math.max(308, Math.min(332, Math.round(w * 0.335)))
    }

    function paneGap(totalWidth) {
        var w = totalWidth || 0
        if (w < 750) return 10
        if (w < 860) return 14
        return 20
    }

    function gridGap(totalHeight) {
        var h = totalHeight || 0
        if (h < 450) return 8
        if (h < 540) return 10
        return 14
    }

    function cpuCardPadding(totalHeight, totalWidth) {
        if ((totalHeight || 0) < 450 || (totalWidth || 0) < 750) return 14
        if ((totalHeight || 0) < 540 || (totalWidth || 0) < 860) return 16
        return 19
    }

    function focusCardPadding(totalHeight, totalWidth) {
        if ((totalHeight || 0) < 450 || (totalWidth || 0) < 750) return 14
        if ((totalHeight || 0) < 540 || (totalWidth || 0) < 860) return 17
        return 20
    }

    function compactCardPadding(totalHeight, totalWidth) {
        if ((totalHeight || 0) < 450 || (totalWidth || 0) < 750) return 13
        if ((totalHeight || 0) < 540 || (totalWidth || 0) < 860) return 15
        return 17
    }

    function processPanePadding(totalHeight, totalWidth) {
        if ((totalHeight || 0) < 450 || (totalWidth || 0) < 750) return 14
        if ((totalHeight || 0) < 540 || (totalWidth || 0) < 860) return 17
        return 20
    }

    // Fit telemetry cards to the available height.
    function cpuCardHeight(totalHeight) {
        var h = totalHeight || 0
        if (h < 450) return 114
        if (h < 540) return 136
        return 166
    }

    function focusCardHeight(totalHeight) {
        var h = totalHeight || 0
        if (h < 450) return 112
        if (h < 540) return 136
        return 160
    }

    function compactCardHeight(totalHeight) {
        var h = Math.max(360, totalHeight || 0)
        var gap = gridGap(h)
        var remaining = h - cpuCardHeight(h) - focusCardHeight(h) - (3 * gap)
        var derived = Math.floor(remaining / 2)
        if (h < 450) return Math.max(62, Math.min(72, derived))
        if (h < 540) return Math.max(76, Math.min(88, derived))
        return Math.max(88, Math.min(100, derived))
    }

    // Derive surface colors from the current theme.
    readonly property color shellSurface: Theme.surface
    readonly property color paneSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.042)
        : Qt.alpha(Theme.hoverMuted, 0.22)
    readonly property color cardSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.045)
        : Qt.alpha(Theme.hoverMuted, 0.24)
    readonly property color focusSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.078)
        : Qt.alpha(Theme.hoverMuted, 0.35)
    readonly property color activeCardSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.088)
        : Qt.alpha(Theme.hoverMuted, 0.38)
    readonly property color hoverSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.068)
        : Qt.alpha(Theme.hoverMuted, 0.31)
    readonly property color keyFocusSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.105)
        : Qt.alpha(Theme.hoverMuted, 0.44)
    readonly property color controlSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.055)
        : Qt.alpha(Theme.overlayInk, 0.042)
    readonly property color controlFocusSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.092)
        : Qt.alpha(Theme.overlayInk, 0.078)
    readonly property color wellSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.038)
        : Qt.alpha(Theme.overlayInk, 0.032)
    readonly property color trackSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.085)
        : Qt.alpha(Theme.overlayInk, 0.075)
    readonly property color popupSurface: Theme.isLight
        ? Qt.darker(Theme.surface, 1.04)
        : Qt.lighter(Theme.surface, 1.55)
    readonly property color selectedSurface: Qt.alpha(Theme.accent, Theme.isLight ? 0.13 : 0.11)
    readonly property color rowSelectedSurface: selectedSurface
    readonly property color rowHoverSurface: Theme.isLight
        ? Qt.alpha(Theme.overlayInk, 0.038)
        : Qt.alpha(Theme.overlayInk, 0.032)
    readonly property color dangerSurface: Qt.alpha(Theme.dangerFill, Theme.isLight ? 0.12 : 0.16)
    readonly property color primaryFg: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.88 : 0.90)
    readonly property color secondaryFg: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.66 : 0.68)
    readonly property color headerAccentFg: Qt.alpha(Theme.accent, Theme.isLight ? 0.72 : 0.68)
    readonly property color barFill: Qt.alpha(Theme.accent, Theme.isLight ? 0.88 : 0.85)
    readonly property color compactBarFill: Qt.alpha(Theme.accent, Theme.isLight ? 0.68 : 0.64)
    readonly property color coreIdleFill: Qt.alpha(Theme.accent, Theme.isLight ? 0.76 : 0.72)
    readonly property color barSecondaryFill: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.36 : 0.42)

    // Scale typography with the theme font size.
    readonly property int windowTitleSize: Math.max(13, Theme.fontSize)
    readonly property int sectionTitleSize: Math.max(12, Theme.fontSize - 1)
    readonly property int heroFontSize: Math.max(17, Theme.fontSize + 4)
    readonly property int focusHeroFontSize: Math.max(17, Theme.fontSize + 4)
    readonly property int bodyFontSize: Math.max(12, Theme.fontSize - 1)
    readonly property int tableFontSize: Math.max(12, Theme.fontSize - 2)
    readonly property int metaFontSize: Math.max(11, Theme.fontSize - 3)

    // Show unavailable values as an em dash.
    function dashMetric(value, suffix, digits) {
        if (value === null || value === undefined || !Number.isFinite(value)) return "—"
        var d = digits === undefined ? 1 : digits
        return value.toFixed(d) + (suffix || "")
    }

    function dashBytes(value) {
        if (value === null || value === undefined || !Number.isFinite(value)) return "—"
        return Logic.bytes(value)
    }

    function dashRate(value) {
        if (value === null || value === undefined || !Number.isFinite(value)) return "—"
        return Logic.bytes(value) + "/s"
    }

    function dashPairBytes(used, total) {
        if (used === null || used === undefined || total === null || total === undefined
                || !Number.isFinite(used) || !Number.isFinite(total) || total <= 0) {
            return "—"
        }
        return Logic.bytes(used) + " / " + Logic.bytes(total)
    }

    function clampPercent(value) {
        if (value === null || value === undefined || !Number.isFinite(value)) return 0
        return Math.max(0, Math.min(100, value))
    }

    function gpuHeroText(gpu, serviceReady) {
        if (!gpu) return serviceReady ? "Unsupported" : "—"
        if (Number.isFinite(gpu.usage)) return dashMetric(gpu.usage, "%")
        var statusText = Logic.gpuUsage(gpu)
        return statusText === "Unavailable" ? "—" : statusText
    }

    function truncateEnd(text, maxChars) {
        if (!text) return ""
        var s = String(text)
        var limit = maxChars || 32
        if (s.length <= limit) return s
        return s.slice(0, Math.max(1, limit - 1)) + "…"
    }

    function truncateMiddle(text, maxChars) {
        if (!text) return ""
        var s = String(text)
        var limit = maxChars || 88
        if (s.length <= limit) return s
        var half = Math.floor((limit - 3) / 2)
        return s.slice(0, half) + "…" + s.slice(s.length - half)
    }
}
