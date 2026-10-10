pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property SystemClock _clock: SystemClock {}
    readonly property var date: _clock.date
}
