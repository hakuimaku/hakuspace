pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Shell-owned surfaces remain reactive across generated theme updates.
    readonly property color surface: ShellSettingsStore.surfaceTone === "ink" ? "#000000"
                                      : ShellSettingsStore.surfaceTone === "soft" ? "#171717" : "#0b0b0b"
    readonly property color onAccentColor: root.surface
    property string fg: "#ffffff"
    property string fgDim: "#aaaaaa"
    // Descriptions stay neutral when generated secondary text has a tint.
    readonly property color fgDescription: Qt.hsla(0, 0, Qt.darker(root.fgDim, 1).hslLightness, 1)
    property string fgMuted: "#80ffffff"
    property string border: "transparent"
    property color surfaceHi: root.accent
    readonly property string hoverMuted: ShellSettingsStore.surfaceTone === "ink" ? "#202020"
                                         : ShellSettingsStore.surfaceTone === "soft" ? "#333333" : "#2b2b2b"
    property string accent: "#ffffff"
    // Blue marks movement and focus shortcuts in the Settings guide.
    readonly property color guideNavigation: "#8bb9e8"
    // Sage marks guarded editing actions in the Settings guide.
    readonly property color guideActions: "#a7c4a0"
    // Lavender marks code-editor shortcuts in the Settings guide.
    readonly property color guideEditing: "#c6aedb"
    // Sand marks reading and help shortcuts in the Settings guide.
    readonly property color guideReading: "#d9bd8c"
    // Shared timing and foreground for the shell-mode wipe.
    readonly property color shellTransitionBlack: "#000000"
    readonly property int shellTransitionAccentDuration: 560
    readonly property int shellTransitionBlackDuration: 400
    readonly property int shellTransitionBlackDelay: 60
    readonly property int shellTransitionHoldDuration: 240
    property string workspaceDot: "#424242"
    
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
            if (conf.surfaceHi) root.surfaceHi = parseColor(conf.surfaceHi);
            if (conf.fg) root.fg = parseColor(conf.fg);
            if (conf.fgDim) root.fgDim = parseColor(conf.fgDim);
            if (conf.fgMuted) root.fgMuted = parseColor(conf.fgMuted);
            if (conf.border) root.border = parseColor(conf.border);
            if (conf.accent) root.accent = parseColor(conf.accent);
            
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
