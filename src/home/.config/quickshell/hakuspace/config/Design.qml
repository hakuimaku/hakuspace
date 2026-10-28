pragma Singleton
import QtQuick

QtObject {
    // Fallback accentSeed before generated theme overrides.
    readonly property string defaultAccentSeed: "#ffffff"

    // Fallback accentDark before generated theme overrides.
    readonly property color defaultAccentDark: "#ffffff"

    // Fallback accentLight before generated theme overrides.
    readonly property color defaultAccentLight: "#414141"

    // Fallback border before generated theme overrides.
    readonly property string defaultBorder: "transparent"

    // Fallback borderWidth before generated theme overrides.
    readonly property int defaultBorderWidth: 0

    // Fallback gap before generated theme overrides.
    readonly property int defaultGap: 4

    // Fallback pad before generated theme overrides.
    readonly property int defaultPad: 10

    // Fallback font before generated theme overrides.
    readonly property string defaultFont: "sans-serif"

    // Fallback fontSize before generated theme overrides.
    readonly property int defaultFontSize: 14

    // Light palette surfaceInk color.
    readonly property color surfaceInkLight: "#ffffff"

    // Dark palette surfaceInk color.
    readonly property color surfaceInkDark: "#000000"

    // Light palette surfaceSoft color.
    readonly property color surfaceSoftLight: "#d6d6d6"

    // Dark palette surfaceSoft color.
    readonly property color surfaceSoftDark: "#171717"

    // Light palette surfaceDark color.
    readonly property color surfaceDefaultLight: "#eeeeee"

    // Dark palette surfaceDark color.
    readonly property color surfaceDefaultDark: "#0b0b0b"

    // Light palette onAccent color.
    readonly property color onAccentLight: "#ffffff"

    // Dark palette onAccent color.
    readonly property color onAccentDark: "#000000"

    // Light palette fgMuted color.
    readonly property color fgMutedLight: "#99000000"

    // Dark palette fgMuted color.
    readonly property color fgMutedDark: "#80ffffff"

    // Light palette hoverInk color.
    readonly property color hoverInkLight: "#e9e9e9"

    // Dark palette hoverInk color.
    readonly property color hoverInkDark: "#202020"

    // Light palette hoverSoft color.
    readonly property color hoverSoftLight: "#c0c0c0"

    // Dark palette hoverSoft color.
    readonly property color hoverSoftDark: "#333333"

    // Light palette hoverDark color.
    readonly property color hoverDefaultLight: "#d7d7d7"

    // Dark palette hoverDark color.
    readonly property color hoverDefaultDark: "#2b2b2b"

    // Light palette overlayInk color.
    readonly property color overlayInkLight: "#000000"

    // Dark palette overlayInk color.
    readonly property color overlayInkDark: "#ffffff"

    // Light palette guideNavigation color.
    readonly property color guideNavigationLight: "#285786"

    // Dark palette guideNavigation color.
    readonly property color guideNavigationDark: "#8bb9e8"

    // Light palette guideActions color.
    readonly property color guideActionsLight: "#3d6536"

    // Dark palette guideActions color.
    readonly property color guideActionsDark: "#a7c4a0"

    // Light palette guideEditing color.
    readonly property color guideEditingLight: "#694581"

    // Dark palette guideEditing color.
    readonly property color guideEditingDark: "#c6aedb"

    // Light palette guideReading color.
    readonly property color guideReadingLight: "#70501f"

    // Dark palette guideReading color.
    readonly property color guideReadingDark: "#d9bd8c"

    // Light palette danger color.
    readonly property color dangerLight: "#b32020"

    // Dark palette danger color.
    readonly property color dangerDark: "#ff6b6b"

    // Light palette dangerFill color.
    readonly property color dangerFillLight: "#b32020"

    // Dark palette dangerFill color.
    readonly property color dangerFillDark: "#e05555"

    // Light palette warning color.
    readonly property color warningLight: "#805600"

    // Dark palette warning color.
    readonly property color warningDark: "#ffaa00"

    // Light palette success color.
    readonly property color successLight: "#356329"

    // Dark palette success color.
    readonly property color successDark: "#98c379"

    // Light palette workspaceDot color.
    readonly property color workspaceDotLight: "#a0a0a0"

    // Dark palette workspaceDot color.
    readonly property color workspaceDotDark: "#424242"

    // Light palette description text.
    readonly property color fgDescriptionLight: "#595959"

    // Opacity for onAccentMuted.
    readonly property real onAccentMutedOpacity: 0.7

    // Opacity for fgDim.
    readonly property real fgDimOpacity: 0.8

    // Opacity for scrollbarIdle.
    readonly property real scrollbarIdleOpacity: 0.4

    // Opacity for scrollbarHover.
    readonly property real scrollbarHoverOpacity: 0.7

    // Offset from the runtime base radius.
    readonly property int largeRadiusOffset: 4

    // Offset from the runtime base radius.
    readonly property int hugRadiusOffset: 16

    // Offset from the runtime base radius.
    readonly property int giantRadiusOffset: 36

    // Shared shellTransitionBlack token.
    readonly property color shellTransitionBlack: "#000000"

    // Shared spaceXs token.
    readonly property int spaceXs: 4

    // Shared spaceSm token.
    readonly property int spaceSm: 8

    // Shared spaceMd token.
    readonly property int spaceMd: 12

    // Shared spaceLg token.
    readonly property int spaceLg: 16

    // Shared spaceXl token.
    readonly property int spaceXl: 24

    // Shared panelPadding token.
    readonly property int panelPadding: 24

    // Shared cardPadding token.
    readonly property int cardPadding: 16

    // Shared controlHeight token.
    readonly property int controlHeight: 36

    // Shared comfortableControlHeight token.
    readonly property int comfortableControlHeight: 40

    // Shared sectionGap token.
    readonly property int sectionGap: 24

    // Shared topBarTopPadding token.
    readonly property int topBarTopPadding: 4

    // Shared topBarBottomPadding token.
    readonly property int topBarBottomPadding: 4

    // Shared levelOsdPadding token.
    readonly property int levelOsdPadding: 8

    // Sizing constant for topBarMinContentHeight.
    readonly property real topBarMinContentHeight: 30

    // Sizing constant for topBarFontHeightFactor.
    readonly property real topBarFontHeightFactor: 2.3

    // Sizing constant for levelOsdMinWidth.
    readonly property real levelOsdMinWidth: 240

    // Sizing constant for levelOsdFontWidthFactor.
    readonly property real levelOsdFontWidthFactor: 22

    // Sizing constant for levelOsdMinHeight.
    readonly property real levelOsdMinHeight: 36

    // Sizing constant for levelOsdFontHeightFactor.
    readonly property real levelOsdFontHeightFactor: 2.4
}
