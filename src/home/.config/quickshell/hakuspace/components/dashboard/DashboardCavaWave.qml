import QtQuick
import "../../services"

Item {
    id: root
    clip: true

    readonly property bool hasAudio: Media.playing && Cava.levels && Cava.levels.length > 0
    opacity: hasAudio ? 0.38 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: HAnimation.slow
            easing.bezierCurve: HAnimation.moduleCurve
        }
    }

    Row {
        id: barRow
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.bottomMargin: 0
        spacing: Math.max(4, Math.floor((width - (12 * barWidth)) / 11))

        readonly property real barWidth: Math.max(6, Math.floor((width - (11 * 6)) / 12))

        Repeater {
            model: 12
            Rectangle {
                id: bar
                width: barRow.barWidth
                anchors.bottom: parent.bottom
                readonly property real level: (Cava.levels && Cava.levels.length > index) ? Cava.levels[index] : 0.0
                height: Math.max(3, Math.round(parent.height * 0.90 * level))
                radius: Math.min(width / 2, 4)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.80) }
                    GradientStop { position: 1.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) }
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
