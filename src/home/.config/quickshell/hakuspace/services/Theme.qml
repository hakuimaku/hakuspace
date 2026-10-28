pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

QtObject {
    id: root

    // Hikai preferences select a palette without regenerating shared theme files.
    readonly property string colorMode: ShellSettingsStore.colorMode
    readonly property bool isLight: colorMode === "light"
    property string accentSeed: Design.defaultAccentSeed
    property color accentDark: Design.defaultAccentDark
    property color accentLight: Design.defaultAccentLight
    readonly property color accent: isLight ? accentLight : accentDark
    readonly property color surface: ShellSettingsStore.surfaceTone === "ink" ? (isLight ? Design.surfaceInkLight : Design.surfaceInkDark)
                                      : ShellSettingsStore.surfaceTone === "soft" ? (isLight ? Design.surfaceSoftLight : Design.surfaceSoftDark)
                                      : (isLight ? Design.surfaceDefaultLight : Design.surfaceDefaultDark)
    readonly property color onAccentColor: isLight ? Design.onAccentLight : Design.onAccentDark
    readonly property color onAccentMuted: Qt.alpha(onAccentColor, Design.onAccentMutedOpacity)
    readonly property color fg: accent
    readonly property color fgDim: Qt.alpha(accent, Design.fgDimOpacity)
    readonly property color fgDescription: isLight ? Design.fgDescriptionLight : Qt.hsla(0, 0, root.fgDim.hslLightness, 1)
    readonly property color fgMuted: isLight ? Design.fgMutedLight : Design.fgMutedDark
    property string border: Design.defaultBorder
    readonly property color surfaceHi: accent
    readonly property color hoverMuted: ShellSettingsStore.surfaceTone === "ink" ? (isLight ? Design.hoverInkLight : Design.hoverInkDark)
                                         : ShellSettingsStore.surfaceTone === "soft" ? (isLight ? Design.hoverSoftLight : Design.hoverSoftDark)
                                         : (isLight ? Design.hoverDefaultLight : Design.hoverDefaultDark)
    // Neutral overlays reverse polarity with the surface.
    readonly property color overlayInk: isLight ? Design.overlayInkLight : Design.overlayInkDark
    readonly property color scrollbarIdle: Qt.alpha(overlayInk, Design.scrollbarIdleOpacity)
    readonly property color scrollbarHover: Qt.alpha(overlayInk, Design.scrollbarHoverOpacity)
    readonly property color guideNavigation: isLight ? Design.guideNavigationLight : Design.guideNavigationDark
    readonly property color guideActions: isLight ? Design.guideActionsLight : Design.guideActionsDark
    readonly property color guideEditing: isLight ? Design.guideEditingLight : Design.guideEditingDark
    readonly property color guideReading: isLight ? Design.guideReadingLight : Design.guideReadingDark

    // Preserve dark-mode surface relationships while reversing their light-mode polarity.
    function surfaceHighlight(factor) {
        return isLight ? Qt.darker(hoverMuted, factor) : Qt.lighter(hoverMuted, factor)
    }
    function surfaceSubtle(factor) {
        return isLight ? Qt.lighter(hoverMuted, factor) : Qt.darker(hoverMuted, factor)
    }
    // Status colors retain readable text contrast on light surfaces.
    readonly property color danger: isLight ? Design.dangerLight : Design.dangerDark
    readonly property color dangerFill: isLight ? Design.dangerFillLight : Design.dangerFillDark
    readonly property color warning: isLight ? Design.warningLight : Design.warningDark
    readonly property color success: isLight ? Design.successLight : Design.successDark
    // Shared timing and foreground for the shell-mode wipe.
    readonly property color shellTransitionBlack: Design.shellTransitionBlack
    readonly property int shellTransitionAccentDuration: Motion.shellTransitionAccentDuration
    readonly property int shellTransitionBlackDuration: Motion.shellTransitionBlackDuration
    readonly property int shellTransitionBlackDelay: Motion.shellTransitionBlackDelay
    readonly property int shellTransitionHoldDuration: Motion.shellTransitionHoldDuration
    readonly property color workspaceDot: isLight ? Design.workspaceDotLight : Design.workspaceDotDark
    
    // Preserve the generated baseline with one shell-owned radius family.
    readonly property int radius: ShellSettingsStore.baseRadius
    readonly property int largeRadius: radius + Design.largeRadiusOffset
    readonly property int hugRadius: radius + Design.hugRadiusOffset
    readonly property int giantRadius: radius + Design.giantRadiusOffset
    property int borderWidth: Design.defaultBorderWidth
    property int gap: Design.defaultGap
    property int pad: Design.defaultPad
    // Comfortable metrics for floating panels, text cards and their controls.
    readonly property int spaceXs: Design.spaceXs
    readonly property int spaceSm: Design.spaceSm
    readonly property int spaceMd: Design.spaceMd
    readonly property int spaceLg: Design.spaceLg
    readonly property int spaceXl: Design.spaceXl
    readonly property int panelPadding: Design.panelPadding
    readonly property int cardPadding: Design.cardPadding
    readonly property int controlHeight: Design.controlHeight
    readonly property int comfortableControlHeight: Design.comfortableControlHeight
    readonly property int sectionGap: Design.sectionGap
    
    property string font: Design.defaultFont
    property string fontFamily: font
    property int fontSize: Design.defaultFontSize
    readonly property int topBarTopPadding: Design.topBarTopPadding
    readonly property real topBarContentHeight: Math.max(Design.topBarMinContentHeight, fontSize * Design.topBarFontHeightFactor) + topBarTopPadding
    readonly property int topBarBottomPadding: Design.topBarBottomPadding
    readonly property real topBarHeight: topBarContentHeight + topBarBottomPadding
    readonly property real levelOsdWidth: Math.max(Design.levelOsdMinWidth, fontSize * Design.levelOsdFontWidthFactor)
    readonly property int levelOsdPadding: Design.levelOsdPadding
    readonly property real levelOsdHeight: Math.max(Design.levelOsdMinHeight, fontSize * Design.levelOsdFontHeightFactor + 2 * (levelOsdPadding + gap))
    
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
