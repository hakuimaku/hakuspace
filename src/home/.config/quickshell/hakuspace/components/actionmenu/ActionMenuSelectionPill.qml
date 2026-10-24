import QtQuick
import "../../services"
import "../motion" as Motion

// Selection pill indicator for list and grid items in ActionMenu pages.
Motion.SelectionPill {
    id: root
    // Use a slower monotonic fade so text and background never overshoot together.
    fadeDuration: 480
    fadeCurve: HAnimation.actionLayerDataFadeCurve

    // Find the owning page through layouts and ListView content items.
    readonly property Item page: {
        var item = parent
        while (item && item.selectionPillShown === undefined) item = item.parent
        return item
    }

    // Reuse SelectionPill's opacity animation without resetting its selected target.
    opacity: shown && (!page || page.selectionPillShown) ? 1 : 0

    // Initialize hidden-page geometry on return so the next hover animates normally.
    onShownChanged: {
        if (shown) syncTarget(true)
        else absoluteInitialized = false
    }

    Binding {
        target: root.page
        property: "selectionPillOpacity"
        value: Math.max(0, Math.min(1, root.opacity))
    }

    // Ignore button feedback transforms when mapping the selection's layout rectangle.
    function syncTarget(forceSnap) {
        if (!targetItem || targetItem.width <= 0 || targetItem.height <= 0) return
        var container = coordinateSpace || parent
        if (!container || !targetItem.parent) return
        var point = targetItem.parent.mapToItem(container, targetItem.x, targetItem.y)
        targetX = point.x
        targetY = point.y
        targetWidth = targetItem.width
        targetHeight = targetItem.height
        targetRadius = targetItem.radius > 0 ? targetItem.radius : Theme.radius
        targetColor = targetItem.danger === true ? dangerColor : normalColor
        if (!absoluteInitialized || forceSnap) snap()
    }

    Connections {
        target: root.targetItem ? root.targetItem.parent : null
        function onXChanged() { root.syncTarget(false) }
        function onYChanged() { root.syncTarget(false) }
    }
}
