pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string accent: "#c89a6a"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14
    
    property string bg: "#b3000000"
    property string surface: "#99202020"
    property string surfaceHi: "#c89a6a"
    property string border: "transparent"
    
    property string fg: "#c89a6a"
    property string fgDim: "#ccc89a6a"
    property string fgMuted: "#80ffffff"
    property string onAccentColor: "#000000"

    property int radius: 12
    property int radiusSm: 8
    property int borderWidth: 0
    property int gap: 4
    property int pad: 10

    property bool shadow: true
    property bool blur: true
    property bool opaqueTheme: false

    function parseColor(c) {
        if (!c) return "transparent";
        if (c.startsWith("#")) return c;
        if (c === "transparent") return c;
        var m = c.match(/^rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)$/);
        if (m) {
            var r = parseInt(m[1]).toString(16).padStart(2, '0');
            var g = parseInt(m[2]).toString(16).padStart(2, '0');
            var b = parseInt(m[3]).toString(16).padStart(2, '0');
            var a = m[4] ? Math.round(parseFloat(m[4]) * 255).toString(16).padStart(2, '0') : "ff";
            return "#" + a + r + g + b;
        }
        return c; 
    }

    function _readJson(path, callback) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0)) {
                try { callback(JSON.parse(xhr.responseText)); } catch(e) {}
            }
        }
        xhr.send();
    }
    
    function _readText(path, callback) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0)) {
                callback(xhr.responseText);
            }
        }
        xhr.send();
    }

    function reload() {
        _readJson(Env.themeDir + "/quickshell.json", function(data) {
            root.accent = parseColor(data.accent);
            root.fontFamily = data.fontFamily;
            root.fontSize = data.fontSize;
            
            root.bg = parseColor(data.colors.bg);
            root.surface = parseColor(data.colors.surface);
            root.surfaceHi = parseColor(data.colors.surfaceHi);
            root.border = parseColor(data.colors.border);
            
            root.fg = parseColor(data.colors.fg);
            root.fgDim = parseColor(data.colors.fgDim);
            root.fgMuted = parseColor(data.colors.fgMuted);
            root.onAccentColor = parseColor(data.colors.onAccent);
            
            root.radius = data.shape.radius;
            root.radiusSm = data.shape.radiusSm;
            root.borderWidth = data.shape.borderWidth;
            root.gap = data.shape.gap;
            root.pad = data.shape.pad;
            
            root.shadow = data.effects.shadow;
            root.blur = data.effects.blur;
        });
        _readText(Env.stateDir + "/opaque_theme_state", function(data) {
            root.opaqueTheme = (data.trim() === "1");
        });
    }

    Component.onCompleted: reload()
}
