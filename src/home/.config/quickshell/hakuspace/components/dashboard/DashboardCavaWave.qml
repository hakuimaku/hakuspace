import QtQuick
import "../../services"

Item {
    id: root
    clip: true

    readonly property color accentColor: Theme.accent
    readonly property bool hasAudio: Media.playing && Cava.levels && Cava.levels.length > 0
    opacity: hasAudio ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: HAnimation.slow
            easing.bezierCurve: HAnimation.moduleCurve
        }
    }

    Row {
        id: barRow
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 6
        spacing: Math.max(4, Math.floor((width - (12 * barWidth)) / 11))

        readonly property real barWidth: Math.max(6, Math.floor((width - (11 * 4)) / 12))

        Repeater {
            model: 12
            Rectangle {
                id: bar
                width: barRow.barWidth
                anchors.bottom: parent.bottom
                readonly property real level: (Cava.levels && Cava.levels.length > index) ? Cava.levels[index] : 0.0
                height: Math.max(3, Math.round(barRow.height * 0.88 * level))
                radius: Math.min(width / 2, 4)
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
