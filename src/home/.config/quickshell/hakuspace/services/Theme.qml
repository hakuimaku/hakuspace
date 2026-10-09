pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string bg: "#b3000000"
    property string fg: "#ffffff"
    property string fgDim: "#aaaaaa"
    property string scrim: "#80000000"
    property string fgMuted: "#80ffffff"
    property string border: "transparent"
    property string surface: "#99202020"
    property string surfaceHi: "#444444"
    property string accent: "#ffffff"
    property string onAccentColor: "#000000"
    property string inkBg: "#111111"
    
    property int radius: 16
    property int radiusSm: 8
    property int tipHugRadius: 24
    property int borderWidth: 0
    property int gap: 4
    property int pad: 10
    
    property string font: "sans-serif"
    property string fontFamily: font
    property int fontSize: 14
    
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

    function apply(jsonString) {
        if (!jsonString || jsonString.trim() === "") return;
        try {
            var conf = JSON.parse(jsonString);
            if (conf.bg) root.bg = parseColor(conf.bg);
            if (conf.fg) root.fg = parseColor(conf.fg);
            if (conf.fgDim) root.fgDim = parseColor(conf.fgDim);
            if (conf.fgMuted) root.fgMuted = parseColor(conf.fgMuted);
            if (conf.border) root.border = parseColor(conf.border);
            if (conf.surface) root.surface = parseColor(conf.surface);
            if (conf.surfaceHi) root.surfaceHi = parseColor(conf.surfaceHi);
            if (conf.accent) root.accent = parseColor(conf.accent);
            if (conf.onAccent) root.onAccentColor = parseColor(conf.onAccent);
            
            if (conf.radius !== undefined) {
                root.radius = conf.radius;
                root.radiusSm = Math.max(0, conf.radius - 4);
            }
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

    property FileView themeFile: FileView {
        path: Env.themeDir + "/quickshell.json"
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onTextChanged: root.apply(this.text().trim())
    }
}
