import "../../services"
import "../flare" as Flare
import QtQuick

Flare.FlareSurface {
    id: root

    readonly property real spanWidth: Math.min(Theme.levelOsdWidth + Theme.levelOsdPadding * 2, Math.max(0, bounds.end - bounds.start - 2 * (Theme.largeRadius + 8)))

    // Share the visual bridge while CenterState retains the level-feedback state.
    width: parent.width
    start: (width - spanWidth) / 2
    end: (width + spanWidth) / 2
    currentHeight: Theme.levelOsdHeight * CenterState.osdExpansion
    bounds: ScreenGeometry.horizontalBounds(width)
    r: Theme.largeRadius + 8
    rf: Theme.hugRadius
    surfaceColor: Theme.surface
    visible: CenterState.osdExpansion > 0 && spanWidth > 0
}
