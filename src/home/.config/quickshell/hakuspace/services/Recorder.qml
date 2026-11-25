pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property bool isRecording: false
    property string recordTime: ""

    property bool _pidPresent: false
    property string _rawTime: ""

    function _sync() {
        root.isRecording = root._pidPresent
        root.recordTime = root._pidPresent ? root._rawTime : ""
    }

    // record_ctl.sh creates /tmp/recording_pid, updates /tmp/recording_time every second, and removes both on stop.
    property FileView pidFile: FileView {
        path: "/tmp/recording_pid"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: {
            root._pidPresent = text().trim().length > 0
            root._sync()
        }
        onLoadFailed: {
            root._pidPresent = false
            root._sync()
        }
    }

    property FileView timeFile: FileView {
        path: "/tmp/recording_time"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: {
            var value = text().trim()
            if (value.length > 0 || !root._pidPresent) {
                root._rawTime = value
                root._sync()
            }
        }
        onLoadFailed: {
            root._rawTime = ""
            root._sync()
        }
    }
}
