pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Hikai preferences select a palette without regenerating shared theme files.
    readonly property string colorMode: ShellSettingsStore.colorMode
    readonly property bool isLight: colorMode === "light"
    property string accentSeed: "#ffffff"
    property color accentDark: "#ffffff"
    property color accentLight: "#414141"
    readonly property color accent: isLight ? accentLight : accentDark
    readonly property color surface: ShellSettingsStore.surfaceTone === "ink" ? (isLight ? "#ffffff" : "#000000")
                                      : ShellSettingsStore.surfaceTone === "soft" ? (isLight ? "#d6d6d6" : "#171717")
                                      : (isLight ? "#eeeeee" : "#0b0b0b")
    readonly property color onAccentColor: isLight ? "#ffffff" : "#000000"
    readonly property color onAccentMuted: Qt.alpha(onAccentColor, 0.7)
    readonly property color fg: accent
    readonly property color fgDim: Qt.alpha(accent, 0.8)
    readonly property color fgDescription: isLight ? "#595959" : Qt.hsla(0, 0, root.fgDim.hslLightness, 1)
    readonly property color fgMuted: isLight ? "#99000000" : "#80ffffff"
    property string border: "transparent"
    readonly property color surfaceHi: accent
    readonly property color hoverMuted: ShellSettingsStore.surfaceTone === "ink" ? (isLight ? "#e9e9e9" : "#202020")
                                         : ShellSettingsStore.surfaceTone === "soft" ? (isLight ? "#c0c0c0" : "#333333")
                                         : (isLight ? "#d7d7d7" : "#2b2b2b")
    // Neutral overlays reverse polarity with the surface.
    readonly property color overlayInk: isLight ? "#000000" : "#ffffff"
    readonly property color scrollbarIdle: Qt.alpha(overlayInk, 0.4)
    readonly property color scrollbarHover: Qt.alpha(overlayInk, 0.7)
    readonly property color guideNavigation: isLight ? "#285786" : "#8bb9e8"
    readonly property color guideActions: isLight ? "#3d6536" : "#a7c4a0"
    readonly property color guideEditing: isLight ? "#694581" : "#c6aedb"
    readonly property color guideReading: isLight ? "#70501f" : "#d9bd8c"

    // Preserve dark-mode surface relationships while reversing their light-mode polarity.
    function surfaceHighlight(factor) {
        return isLight ? Qt.darker(hoverMuted, factor) : Qt.lighter(hoverMuted, factor)
    }
    function surfaceSubtle(factor) {
        return isLight ? Qt.lighter(hoverMuted, factor) : Qt.darker(hoverMuted, factor)
    }
    // Status colors retain readable text contrast on light surfaces.
    readonly property color danger: isLight ? "#b32020" : "#ff6b6b"
    readonly property color dangerFill: isLight ? "#b32020" : "#e05555"
    readonly property color warning: isLight ? "#805600" : "#ffaa00"
    readonly property color success: isLight ? "#356329" : "#98c379"
    // Shared timing and foreground for the shell-mode wipe.
    readonly property color shellTransitionBlack: "#000000"
    readonly property int shellTransitionAccentDuration: 560
    readonly property int shellTransitionBlackDuration: 400
    readonly property int shellTransitionBlackDelay: 60
    readonly property int shellTransitionHoldDuration: 240
    readonly property color workspaceDot: isLight ? "#a0a0a0" : "#424242"
    
    // Preserve the generated baseline with one shell-owned radius family.
    readonly property int radius: ShellSettingsStore.baseRadius
    readonly property int largeRadius: radius + 4
    readonly property int hugRadius: radius + 16
    readonly property int giantRadius: radius + 36
    property int borderWidth: 0
    property int gap: 4
    property int pad: 10
    // Comfortable metrics for floating panels, text cards and their controls.
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int spaceXl: 24
    readonly property int panelPadding: 24
    readonly property int cardPadding: 16
    readonly property int controlHeight: 36
    readonly property int comfortableControlHeight: 40
    readonly property int sectionGap: 24
    
    property string font: "sans-serif"
    property string fontFamily: font
    property int fontSize: 14
    readonly property int topBarTopPadding: 4
    readonly property real topBarContentHeight: Math.max(30, fontSize * 2.3) + topBarTopPadding
    readonly property int topBarBottomPadding: 4
    readonly property real topBarHeight: topBarContentHeight + topBarBottomPadding
    readonly property real levelOsdWidth: Math.max(240, fontSize * 22)
    readonly property int levelOsdPadding: 8
    readonly property real levelOsdHeight: Math.max(36, fontSize * 2.4 + 2 * (levelOsdPadding + gap))
    
    // Convert rgba() to Qt-compatible #AARRGGBB before applying theme data.
    function parseColor(c) {
        if (!c) return "#000000";
        var rgbaMatch = c.match(/^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$/);
        if (rgbaMatch) {
            var r = parseInt(rgbaMatch[1]);
            var g = parseInt(rgbaMatch[2]);
            var b = parseInt(rgbaMatch[3]);
            var a = Math.round(parseFloat(rgbaMatch[4]) * 255);
            return "#" + (a < 16 ? "0" : "") + a.toString(16) +
                   (r < 16 ? "0" : "") + r.toString(16) +
                   (g < 16 ? "0" : "") + g.toString(16) +
                   (b < 16 ? "0" : "") + b.toString(16);
        }
        return c;
    }

    // Parses quickshell.json payload and updates reactive theme properties.
    function apply(jsonString) {
        if (!jsonString || jsonString.trim() === "") return;
        try {
            var conf = JSON.parse(jsonString);
            if (conf.accentSeed || conf.accent) root.accentSeed = conf.accentSeed || conf.accent;
            // Accept legacy dark accents until the controller next regenerates the pair.
            if (conf.accentDark || conf.accent) root.accentDark = parseColor(conf.accentDark || conf.accent);
            if (conf.accentLight) root.accentLight = parseColor(conf.accentLight);
            if (conf.border) root.border = parseColor(conf.border);

            if (conf.borderWidth !== undefined) root.borderWidth = conf.borderWidth;
            if (conf.gap !== undefined) root.gap = conf.gap;
            if (conf.pad !== undefined) root.pad = conf.pad;
            
            if (conf.font) {
                root.font = conf.font;
                root.fontFamily = conf.font;
            }
            if (conf.fontSize !== undefined) root.fontSize = conf.fontSize;
        } catch (e) {
            console.log("Failed to parse quickshell.json: " + e);
        }
    }

    // Watch the generated theme file for live color and sizing updates.
    property FileView themeFile: FileView {
        path: Env.themeDir + "/quickshell.json"
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onTextChanged: root.apply(this.text().trim())
    }
}
