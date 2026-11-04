#!/usr/bin/env python3
"""Exercise the production maintenance bindings against individual worker states."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

# Read the exact QML bindings instead of duplicating their Boolean expressions.
ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'src/home/.config/quickshell/hakuspace/services/WallpaperService.qml'


class MaintenanceTests(unittest.TestCase):
    """Keep every in-flight operation gated and tolerate nullable teardown state."""

    def test_worker_gates(self):
        source = SOURCE.read_text()
        activity = re.search(r'    property QtObject activity: QtObject \{[\s\S]*?\n    \}', source)[0]
        aliases = '\n'.join(re.findall(r'^    readonly property alias (?:busy|cacheBusy|buildingVideos|maintenanceBusy):.*$', source, re.M))
        states = re.search(r'^    readonly property var rendererStates:.*$', source, re.M)[0]
        shutdown = re.search(r'    function shutdown\(\) \{[\s\S]*?\n    \}', source)[0]
        processes = ('resolver', 'committer', 'imageClearer', 'rollback', 'thumbnailFallback',
                     'preloader', 'maintenance', 'handoff', 'canceller', 'accent', 'statusWriter')
        fields = '\n'.join(f'property var {name}: ({{running: false}})' for name in processes)
        qml = '''import QtQuick
Item {
    id: root
    property var candidate: ({})
    property var prepared: ({})
    property var pendingRequest: null
    property var waitingBuild: null
    property var activeBuild: null
    property var buildQueue: []
    property bool cacheMaintenanceActive: false
    property bool cacheRefreshPending: false
    property var renderer: ({stopping: false, states: {}, shutdown: function() {}})
    function check(expected, label) {
        if (typeof maintenanceBusy === "boolean" && maintenanceBusy === expected) return
        console.error("Maintenance gate failed: " + label)
        Qt.exit(1)
        throw new Error(label)
    }
    Timer {
        interval: 1; running: true
        onTriggered: {
            root.check(false, "inactive")
            for (var name of PROCESS_NAMES) {
                root[name] = {running: true}; root.check(true, name)
                root[name] = {running: false}; root.check(false, name + " completed")
                root[name] = null; root.check(false, name + " absent")
            }
            for (var item of [{name: "candidate", value: {token: "new"}}, {name: "prepared", value: {token: "ready"}},
                {name: "pendingRequest", value: {}}, {name: "waitingBuild", value: {}}, {name: "activeBuild", value: {}},
                {name: "buildQueue", value: [{}]}, {name: "cacheMaintenanceActive", value: true}, {name: "cacheRefreshPending", value: true}]) {
                var previous = root[item.name]
                root[item.name] = item.value; root.check(true, item.name)
                root[item.name] = previous; root.check(false, item.name + " completed")
            }
            root.renderer = {stopping: true, states: {}}; root.check(true, "renderer stopping")
            root.renderer = {stopping: false, states: {A: {incoming: {}}, B: null}}; root.check(true, "incoming frame")
            root.renderer = {stopping: false, states: {A: {incoming: null}, B: null}}; root.check(false, "passive frames")
            root.renderer = {stopping: false, states: null}; root.check(false, "states absent")
            root.renderer = null; root.check(true, "renderer absent blocks maintenance")
            root.renderer = {stopping: false, states: {}, shutdown: function() {}}
            root.shutdown(); root.check(true, "shutdown blocks maintenance")
            root.renderer = null; root.buildQueue = [{}]; root.candidate = null
            root.check(true, "late worker changes cannot reopen maintenance")
            console.info("Wallpaper maintenance gates passed")
            Qt.quit()
        }
    }
'''.replace('PROCESS_NAMES', repr(list(processes)).replace("'", '"'))
        qml += fields + '\n' + activity + '\n' + aliases + '\n' + states + '\n' + shutdown + '\n}\n'
        with tempfile.TemporaryDirectory(prefix='haku-maintenance-') as directory:
            work = Path(directory)
            (work / 'runtime').mkdir(mode=0o700)
            (work / 'shell.qml').write_text(qml)
            environment = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=str(work / 'config'),
                               XDG_CACHE_HOME=str(work / 'cache'), XDG_RUNTIME_DIR=str(work / 'runtime'),
                               DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(work / 'no-bus'),
                               QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
            result = subprocess.run(['quickshell', '-p', str(work / 'shell.qml')], env=environment,
                                    capture_output=True, text=True, timeout=10)
            log = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, log)
            self.assertIn('Wallpaper maintenance gates passed', log)
            self.assertNotRegex(log, r'Unable to assign|TypeError|ReferenceError|Binding loop')


if __name__ == '__main__':
    unittest.main()
