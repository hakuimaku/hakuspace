pragma Singleton
import QtQuick

QtObject {
    readonly property int safeZoneGraceMs: 220
    readonly property real safeZoneMargin: 16
    readonly property real safeZoneAnchorMargin: 10
    readonly property real safeZoneCorridorWidth: 32
    readonly property real pointerModeThreshold: 2
    readonly property int focusRestoreLeaseMs: 180
}
