import QtQuick
import "../../services"
import ".."

TopModule {
    visible: CenterState.centerMode === "media" && Cava.available && Cava.audioVisible
    text: Media.playing && Cava.bars !== "" ? Cava.bars : Array(Cava.barCount + 1).join("▁")
    tooltip: Media.playing ? "Audio Visualizer" : "Media paused"
}
