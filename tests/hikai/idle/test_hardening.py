#!/usr/bin/env python3
"""Drive real Quickshell monitors with fake system boundaries on a selected Wayland display."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import re
import subprocess
import tempfile
import time
import unittest

# Keep the runtime private even when the selected display is the developer's compositor.
ROOT = Path(__file__).resolve().parents[3]
FIXTURES = ROOT / 'tests/support/fixtures'
SPEC = importlib.util.spec_from_file_location('idle_defaults', ROOT / 'src/core/backend/user/hikai_settings_ctl.py')
settings = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(settings)

# Fake actions record after any explicit gate, allowing deterministic in-flight failures.
FAKE = '''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
root=Path(os.environ['HAKUSPACE_IDLE_TEST_ROOT'])
name=Path(sys.argv[0]).name
args=sys.argv[1:]
key={'brightnessctl': {'-s':'save','-r':'restore','set':'dim'}.get(args[0]),
     'dpms_handler.sh': args[0], 'power_ctl.sh': 'suspend'}.get(name, name)
deadline=time.monotonic()+5
while (root/('gate-'+str(key))).exists():
    if time.monotonic()>deadline: sys.exit(2)
    time.sleep(.01)
with (root/'actions.jsonl').open('a') as log:
    log.write(json.dumps({'time':time.time(), 'action':key, 'args':args})+'\\n')
if (root/('fail-'+str(key))).exists(): sys.exit(1)
if name=='brightnessctl':
    if args[0]=='-s': (root/'saved').write_text((root/'brightness').read_text())
    elif args[0]=='-r': (root/'brightness').write_text((root/'saved').read_text())
    elif args[0]=='set': (root/'brightness').write_text(args[1])
elif name=='pactl': print((root/'audio').read_text())
'''
BRIDGE = '''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
root=Path(os.environ['HAKUSPACE_IDLE_TEST_ROOT'])
print('{"event":"ready"}',flush=True)
for line in sys.stdin:
    with (root/'actions.jsonl').open('a') as log:
        log.write(json.dumps({'time':time.time(), 'action':'ack', 'args':[line.strip()]})+'\\n')
'''


class IdleHardeningTests(unittest.TestCase):
    """Assert actual monitor notifications, ownership handoff, and failure recovery."""

    def setUp(self):
        """Copy only idle controllers and retain no connection to production action helpers."""
        if not os.environ.get('WAYLAND_DISPLAY'):
            self.skipTest('ENVIRONMENT FAILURE: a Wayland compositor is required')
        self.temp = tempfile.TemporaryDirectory(prefix='haku-idle-contract-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.shell = self.root/'shell'
        services = self.shell/'services'
        services.mkdir(parents=True)
        self.bin = self.root/'bin'
        self.bin.mkdir()
        for name in ('IdleService.qml',):
            shutil.copy2(ROOT/'src/home/.config/quickshell/hakuspace/services'/name, services/name)
        shutil.copytree(ROOT/'src/home/.config/quickshell/hakuspace/services/idle',services/'idle')
        (services/'qmldir').write_text(''.join(f'singleton {n} 1.0 {n}.qml\n' for n in
                                             ('IdleService','ShellSettingsStore','AppState','Env','LockState')))
        self.state_dir=self.root/'.local/state/hakuspace/state'
        self.state_dir.mkdir(parents=True)
        (self.state_dir/'[shell].backend').write_text('hikai\n')
        env_source=(ROOT/'src/home/.config/quickshell/hakuspace/services/Env.qml').read_text()
        env_source=env_source.replace('Quickshell.shellPath("../../../.local/state/hakuspace/state")', json.dumps(str(self.state_dir)))
        env_source=env_source.replace('Quickshell.shellPath("../../../.local/bin")', json.dumps(str(self.bin)))
        (services/'Env.qml').write_text(env_source)
        shutil.copy2(ROOT/'src/home/.config/quickshell/hakuspace/services/AppState.qml', services/'AppState.qml')
        (services/'LockState.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool locked: false; property bool secure: false; property bool failRequests: false; function requestLock() { if (failRequests) return "error"; locked = true; return "ok" } }\n')
        (services/'ShellSettingsStore.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool ready: true; property var values: ('+json.dumps(settings.DEFAULTS)+'); property var savedValues: ('+json.dumps(settings.DEFAULTS)+') }\n')
        harness=(ROOT/'tests/hikai/idle/harness/hardening.qml').read_text()
        production=(ROOT/'src/home/.config/quickshell/hakuspace/shell.qml').read_text()
        idle_ipc=re.search(r'    IpcHandler \{\n        target: "idle".*?\n    \}',production,re.S).group()
        (self.shell/'shell.qml').write_text(harness.rsplit('}',1)[0]+idle_ipc+'\n}\n')
        for source in ('sys/idle_actions.sh','sys/idle_inhibit.sh','lib/haku_state.sh'):
            shutil.copy2(ROOT/'src/core'/source,self.bin)
        for name in ('brightnessctl','dpms_handler.sh','power_ctl.sh','pactl','notify-send'):
            (self.bin/name).write_text(FAKE)
            (self.bin/name).chmod(0o755)
        (self.bin/'idle_session_watch.py').write_text(BRIDGE)
        (self.bin/'idle_session_watch.py').chmod(0o755)
        (self.root/'brightness').write_text('55%')
        (self.root/'audio').write_text('')
        self.runtime = self.root/'runtime'
        self.runtime.mkdir(mode=0o700)
        # Keep the compositor socket while isolating every native action marker and audio grace file.
        display=os.environ['WAYLAND_DISPLAY']
        if not Path(display).is_absolute(): display=str(Path(os.environ['XDG_RUNTIME_DIR'])/display)
        self.env=dict(os.environ, HOME=str(self.root), XDG_RUNTIME_DIR=str(self.runtime), WAYLAND_DISPLAY=display,
                      QT_QPA_PLATFORM='wayland', HAKUSPACE_IDLE_TEST='1', HAKUSPACE_IDLE_TEST_ROOT=str(self.root),
                      PATH=str(self.bin)+os.pathsep+os.environ['PATH'])
        self.log=(self.root/'quickshell.log').open('w')
        self.addCleanup(self.log.close)
        self.process=subprocess.Popen(['qs','-p',str(self.shell/'shell.qml')],env=self.env,stdout=self.log,stderr=self.log)
        self.addCleanup(self.stop)
        self.wait(lambda s:s['ready'] and s['enabled'])
        if not os.environ.get('HAKUSPACE_IDLE_LIVE_SMOKE'):
            self.pointer=subprocess.Popen(['python3',str(FIXTURES/'wayland_pointer.py')],env=self.env,stdin=subprocess.PIPE,
                                          stdout=subprocess.DEVNULL,stderr=self.log,text=True)
            self.addCleanup(self.stop_pointer)
        self.ipc('retry','100')

    def stop(self):
        """Stop only the private Quickshell process and retain logs on failure."""
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)
        self.log.flush()
        artifact=Path(os.environ.get('HAKUSPACE_IDLE_ARTIFACT_DIR','/tmp/haku-idle-hardening/contracts'))
        artifact.mkdir(parents=True,exist_ok=True)
        shutil.copy2(self.root/'quickshell.log',artifact/(self._testMethodName+'.log'))
        if (self.root/'actions.jsonl').exists():
            shutil.copy2(self.root/'actions.jsonl',artifact/(self._testMethodName+'.actions.jsonl'))

    def stop_pointer(self):
        """Release the virtual input client before deleting its private runtime."""
        self.pointer.stdin.close()
        self.pointer.wait(timeout=5)

    def ipc(self, method, *args):
        """Address the test PID so the developer's normal Hikai cannot receive commands."""
        return subprocess.check_output(['qs','ipc','--pid',str(self.process.pid),'call','probe',method,*args],
                                       env=self.env,text=True,stderr=subprocess.DEVNULL,timeout=3).strip()

    def state(self):
        """Retrieve current QML state and attach load errors to failed probes."""
        try:
            return json.loads(self.ipc('status'))
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            return {}

    def wait(self, predicate, seconds=3):
        """Wait on observable state rather than assuming actions finish after a fixed sleep."""
        deadline=time.monotonic()+seconds
        last={}
        while time.monotonic()<deadline:
            last=self.state()
            if last and predicate(last): return last
            if self.process.poll() is not None: break
            time.sleep(.02)
        self.log.flush()
        self.fail('state deadline: '+json.dumps(last)+'\n'+(self.root/'quickshell.log').read_text())

    def actions(self, action=None):
        """Read append-only fake command evidence without changing native state."""
        path=self.root/'actions.jsonl'
        rows=[json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []
        return [row for row in rows if row['action']==action] if action else rows

    def activity(self):
        """Inject input only into the private compositor used by the automated harness."""
        self.pointer.stdin.write('10 10 1280 720 0\n')
        self.pointer.stdin.flush()

    def fault(self, name, active=True):
        """Control explicit fake-command failure gates without invoking real system actions."""
        path=self.root/name
        if active: path.touch()
        else: path.unlink(missing_ok=True)

    def force(self, stage):
        """Force only the selected test service's normal stage gates."""
        self.assertEqual(self.ipc('force',stage),'ok')

    def test_runtime_policy_rearms_once_and_preserves_applied(self):
        """Timeout/inhibitor changes create one next cycle without synthesizing activity."""
        self.ipc('stagePolicy','0.15','true','true')
        self.wait(lambda s:s['applications']==1)
        self.ipc('stagePolicy','0.8','false','true')
        state=self.wait(lambda s:s['testStage']['armedTimeout']==.8 and s['testStage']['monitorEnabled'])
        self.assertTrue(state['testStage']['applied'])
        self.assertEqual(state['resumes'],0)
        self.activity()
        self.wait(lambda s:s['resumes']==1 and not s['testStage']['applied'])
        for timeout in ('0.7','0.5','0.25'):
            self.ipc('stagePolicy',timeout,'true','true')
        state=self.wait(lambda s:s['applications']==2)
        self.assertEqual(state['testStage']['armedTimeout'],.25)
        self.assertEqual(state['resumes'],1)
        self.ipc('stagePolicy','0.25','true','false')
        self.wait(lambda s:s['resumes']==2 and not s['testStage']['monitorEnabled'])
        self.ipc('stagePolicy','0.15','false','true')
        self.wait(lambda s:s['applications']==3)
        self.assertEqual(self.state()['resumes'],2)

    def test_runtime_timeout_change_and_handoff_without_input_injection(self):
        """The same real monitor/handoff contract can run safely on an existing display."""
        self.ipc('stagePolicy','0.8','true','true')
        self.assertEqual(self.state()['applications'],0)
        self.ipc('stagePolicy','0.15','false','true')
        self.wait(lambda s:s['applications']==1)
        self.ipc('stagePolicy','0.15','false','false')
        self.wait(lambda s:s['resumes']==1)
        self.force('dim')
        self.wait(lambda s:s['dim']['applied'] and not s['mutating'])
        self.ipc('release')
        self.wait(lambda s:s['released'])
        self.ipc('backend','classic')
        self.wait(lambda s:s['released'] and not s['owner'] and not s['recoveryRetry'] and not s['queued'])
        self.ipc('backend','hikai')
        self.wait(lambda s:s['owner'] and s['ready'])
        self.force('dim')
        self.wait(lambda s:s['dim']['applied'] and not s['mutating'])

    def test_timeout_rearm_starts_a_fresh_countdown(self):
        """Elapsed time under the old timeout is not reused by the new subscription."""
        self.ipc('stagePolicy','0.8','true','true')
        self.wait(lambda s:s['testStage']['monitorEnabled'])
        time.sleep(.25)
        self.ipc('stagePolicy','0.2','true','true')
        time.sleep(.08)
        self.assertEqual(self.state()['applications'],0)
        self.wait(lambda s:s['applications']==1)

    def test_real_fileview_and_controller_commit_handshake(self):
        """Production commit functions coordinate with the real FileView and QML release IPC."""
        source=(ROOT/'src/core/sys/haku_backend.sh').read_text()
        names=('commit_backend','native_idle_acquire','native_idle_released','native_idle_inactive','wait_until')
        functions='\n'.join(re.search(r'^'+name+r'\(\) \{.*?^\}',source,re.M|re.S).group() for name in names)
        real_qs=shutil.which('qs')
        (self.bin/'qs').write_text('#!/bin/sh\nif [ "$1" = -c ]; then shift 4; exec '+real_qs+
            ' ipc --pid "$HAKUSPACE_IDLE_TEST_PID" call "$@"; fi\nexec '+real_qs+' "$@"\n')
        (self.bin/'qs').chmod(0o755)
        (self.root/'.local/bin').symlink_to(self.bin,target_is_directory=True)
        (self.bin/'idle_backend_ctl.sh').write_text('''#!/usr/bin/env python3
import json,os,subprocess,sys
from pathlib import Path
root=Path(os.environ['HAKUSPACE_IDLE_TEST_ROOT'])
if sys.argv[1]=='stop-classic':
    (root/'hypridle-count').write_text('0')
    raise SystemExit(0)
backend=(root/'.local/state/hakuspace/state/[shell].backend').read_text().strip()
if backend=='classic':
    state=json.loads(subprocess.check_output([os.environ['HAKUSPACE_REAL_QS'],'ipc','--pid',os.environ['HAKUSPACE_IDLE_TEST_PID'],'call','probe','status']))
    assert state['released'] and not state['owner'] and not state['recoveryRetry'] and not state['queued'],state
(root/'hypridle-count').write_text('1' if backend=='classic' else '0')
''')
        (self.bin/'idle_backend_ctl.sh').chmod(0o755)
        script=self.root/'commit.sh'
        script.write_text('QS_BACKEND_NAME=hikai\nBACKEND_STATE_FILE="$HOME/.local/state/hakuspace/state/[shell].backend"\n'
                          'haku_qs_alive() { return 0; }\n'+functions+'\ncommit_backend "$1"\n')
        env=dict(self.env,HAKUSPACE_IDLE_TEST_PID=str(self.process.pid),HAKUSPACE_REAL_QS=real_qs)
        self.force('dim')
        self.wait(lambda s:s['dim']['applied'] and not s['mutating'])
        for backend in ('classic','hikai'):
            result=subprocess.run(['bash',str(script),backend],env=env,capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.wait(lambda s:s['backend']==backend and (s['ready'] if backend=='hikai' else s['released']))
            self.assertEqual((self.root/'hypridle-count').read_text(),str(int(backend=='classic')))

    def test_pending_recovery_cannot_restore_a_later_dim(self):
        """Native stages wait for cleanup so an old recovery cannot override a new effect."""
        self.force('displayOff')
        self.wait(lambda s:s['displayOff']['applied'] and not s['mutating'])
        self.fault('fail-on')
        self.ipc('event','false','1')
        self.wait(lambda s:s['recoveryRetry'])
        self.assertEqual(self.ipc('force','dim'),'error:inactive-stage')
        self.fault('fail-on',False)
        self.wait(lambda s:s['ready'] and s['enabled'])
        self.force('dim')
        self.wait(lambda s:s['dim']['applied'] and not s['mutating'])
        time.sleep(.2)
        self.assertEqual((self.root/'brightness').read_text(),'10%')

    def test_recovery_retry_cannot_cross_handoff(self):
        """Failed cleanup retains ownership until it succeeds, then cancels every retry."""
        self.force('dim')
        self.wait(lambda s:bool(self.actions('dim')) and not s['mutating'])
        self.fault('fail-restore')
        self.ipc('release')
        state=self.wait(lambda s:s['recoveryRetry'])
        self.assertFalse(state['released'])
        self.assertTrue(state['owner'])
        self.fault('fail-restore',False)
        self.wait(lambda s:s['released'])
        self.ipc('backend','classic')
        count=len(self.actions())
        self.wait(lambda s:s['backend']=='classic' and not s['owner'])
        time.sleep(.2)
        self.assertEqual(len(self.actions()),count)
        self.assertFalse(self.state()['recoveryRetry'])
        self.assertEqual((self.root/'brightness').read_text(),'55%')

    def test_stale_completion_does_not_update_new_generation(self):
        """A gated DPMS result cannot mark a later generation recovered or dispatch work."""
        self.fault('gate-off')
        self.force('displayOff')
        before=self.wait(lambda s:s['mutating'])
        self.ipc('backend','classic')
        self.fault('gate-off',False)
        state=self.wait(lambda s:not s['mutating'])
        self.assertGreater(state['generation'],before['generation'])
        self.assertFalse(state['recovered'])
        self.assertEqual(state['queued'],0)
        self.assertFalse(state['recoveryRetry'])
        self.assertFalse(state['released'])
        self.ipc('backend','hikai')
        self.wait(lambda s:s['ready'] and not s['cleanupRequired'])

    def test_owner_loss_cancels_an_already_scheduled_retry(self):
        """Even a direct backend-file change cannot leave native recovery timers alive."""
        self.force('dim')
        self.wait(lambda s:s['dim']['applied'] and not s['mutating'])
        self.fault('fail-restore')
        self.ipc('resume','dim')
        self.wait(lambda s:s['recoveryRetry'])
        self.ipc('backend','classic')
        self.wait(lambda s:not s['owner'] and not s['recoveryRetry'] and not s['mutating'])
        count=len(self.actions('restore'))
        time.sleep(.2)
        self.assertEqual(len(self.actions('restore')),count)
        self.assertEqual(self.state()['queued'],0)

    def test_disabling_cancels_pending_condition_and_rearms(self):
        """A pending condition cannot survive disabling and re-enabling its stage."""
        self.ipc('stageCondition','false')
        self.ipc('stagePolicy','0.1','true','true')
        self.wait(lambda s:s['testStage']['pending'])
        self.ipc('stagePolicy','0.1','true','false')
        self.wait(lambda s:not s['testStage']['pending'] and not s['testStage']['monitorArmed'])
        self.ipc('stageCondition','true')
        self.ipc('stagePolicy','0.1','false','true')
        self.wait(lambda s:s['applications']==1)

    def test_secure_ack_does_not_wait_for_dpms(self):
        """A blocked or failed DPMS off never delays a secure external-sleep ACK."""
        self.fault('gate-off')
        self.fault('fail-off')
        self.ipc('event','true','1')
        self.wait(lambda s:s['locked'])
        self.assertFalse(self.actions('ack'))
        self.ipc('secure','true')
        self.wait(lambda s:s['sleepAcknowledged']==1 and bool(self.actions('ack')))
        self.assertFalse(self.actions('off'))
        self.fault('gate-off',False)
        self.wait(lambda s:not s['mutating'] and bool(self.actions('off')))
        self.assertLess(self.actions('ack')[0]['time'],self.actions('off')[0]['time'])
        self.ipc('event','true','1')
        self.assertEqual(len(self.actions('ack')),1)
        self.assertFalse(self.actions('suspend'))
        self.ipc('event','false','1')
        self.wait(lambda s:not s['mutating'] and not s['cleanupRequired'])
        restores=len(self.actions('restore'))
        self.ipc('event','false','1')
        self.assertEqual(len(self.actions('restore')),restores)

    def test_insecure_external_and_native_sleep_are_separate(self):
        """Neither path can bypass secure locking, and external sleep never calls power."""
        self.ipc('deadline','100')
        self.ipc('event','true','1')
        self.wait(lambda s:'External sleep lock' in s['error'])
        self.assertFalse(self.actions('ack'))
        self.assertFalse(self.actions('suspend'))
        self.ipc('event','false','1')
        self.wait(lambda s:not s['mutating'])
        self.force('suspend')
        self.wait(lambda s:'Idle suspend canceled' in s['error'])
        self.assertFalse(self.actions('suspend'))
        self.ipc('resume','suspend')
        self.ipc('secure','true')
        self.force('suspend')
        self.wait(lambda s:bool(self.actions('suspend')))

    def test_authoritative_inhibit_and_retry_after_audio_ends(self):
        """Common policy reports browser audio and manual overrides independently of stage callbacks."""
        self.ipc('policy','inhibitOnAudio','true')
        (self.root/'audio').write_text('Sink Input #1\nmedia.class = "Stream/Output/Audio"\nCorked: no\nMute: no\napplication.process.binary = "zen-bin"\n')
        self.wait(lambda s:s['customInhibit']['known'] and s['customInhibit']['audioPolicyEnabled'] and s['customInhibit']['audio'])
        self.force('dim')
        self.wait(lambda s:s['dim']['pending'])
        self.assertFalse(self.actions('dim'))
        (self.root/'audio').write_text('')
        stamp=self.runtime/'hakuspace/idle-audio-timestamp'
        self.wait(lambda s:stamp.exists())
        stamp.write_text(str(int(time.time())-6))
        self.wait(lambda s:s['dim']['applied'] and bool(self.actions('dim')))
        self.wait(lambda s:s['customInhibit']['known'] and not s['customInhibit']['effective'])
        self.ipc('manual','true')
        state=self.wait(lambda s:s['customInhibit']['manual'] and s['customInhibit']['effective'])
        self.assertFalse(state['customInhibit']['audio'])

    def test_failed_dim_restore_dpms_and_suspend_recover(self):
        """Inject each reversible action failure and keep the native service usable."""
        for stage, failure in (('dim','dim'),('displayOff','off')):
            with self.subTest(action=failure):
                self.fault('fail-'+failure)
                self.force(stage)
                self.wait(lambda s:bool(self.actions(failure)) and not s[stage]['applied'])
                self.fault('fail-'+failure,False)
                self.wait(lambda s:s[stage]['applied'])
                self.ipc('resume',stage)
                self.wait(lambda s:not s['mutating'])
        self.force('displayOff')
        self.wait(lambda s:s['displayOff']['applied'] and not s['mutating'])
        self.fault('fail-on')
        self.ipc('event','false','2')
        self.wait(lambda s:s['recoveryRetry'])
        self.fault('fail-on',False)
        self.wait(lambda s:not s['cleanupRequired'] and not s['mutating'])
        self.fault('fail-suspend')
        self.ipc('secure','true')
        self.force('suspend')
        self.wait(lambda s:s['error']=='Idle suspend request failed')
        self.assertTrue(self.state()['owner'])

    def test_helper_failure_blocks_actions(self):
        """Broken audio policy helpers fail closed instead of silently dimming."""
        helper=self.bin/'idle_inhibit.sh'
        helper.write_text('#!/bin/sh\nexit 2\n')
        self.force('dim')
        self.wait(lambda s:s['dim']['pending'] and bool(s['customInhibit']['error']))
        self.assertFalse(self.actions('dim'))

    def test_runtime_logs_explain_blocked_audio_and_are_bounded(self):
        """Production log IPC exposes timeout, inhibitor, and retry decisions without an unbounded history."""
        self.ipc('policy','inhibitOnAudio','true')
        (self.root/'audio').write_text('Sink Input #1\nmedia.class = "Stream/Output/Audio"\nCorked: no\nMute: no\napplication.process.binary = "zen-bin"\n')
        self.wait(lambda s:s['customInhibit']['known'] and s['customInhibit']['audioPolicyEnabled'] and s['customInhibit']['audio'])
        self.force('dim')
        self.wait(lambda s:s['dim']['pending'])
        argv=['qs','ipc','--pid',str(self.process.pid),'call','idle','logs']
        logs=json.loads(subprocess.check_output(argv,env=self.env,text=True))
        self.assertEqual(sum(row['event']=='action-start' and row.get('action')=='claim' for row in logs),1)
        self.assertTrue(any(row['event']=='idle-timeout' and row.get('stage')=='dim' for row in logs))
        self.assertTrue(any(row['event']=='condition-blocked' and row.get('stage')=='dim' for row in logs))
        self.assertTrue(any(row['event']=='inhibitors' and row.get('audio') is True for row in logs))
        self.ipc('logBurst')
        logs=json.loads(subprocess.check_output(argv,env=self.env,text=True))
        self.assertEqual(len(logs),128)
        self.assertEqual(logs[-1]['index'],199)

    def test_audio_does_not_block_dim_when_policy_disabled(self):
        """Active audio does not inhibit dim when inhibitOnAudio policy is disabled."""
        (self.root/'audio').write_text('Sink Input #1\nmedia.class = "Stream/Output/Audio"\nCorked: no\nMute: no\napplication.process.binary = "zen-bin"\n')
        self.wait(lambda s:s['customInhibit']['known'] and not s['customInhibit']['audioPolicyEnabled'] and not s['customInhibit']['audio'] and not s['customInhibit']['effective'])
        self.force('dim')
        self.wait(lambda s:s['dim']['applied'] and not s['dim']['pending'] and not s['mutating'] and bool(self.actions('dim')))
        argv=['qs','ipc','--pid',str(self.process.pid),'call','idle','logs']
        logs=json.loads(subprocess.check_output(argv,env=self.env,text=True))
        self.assertFalse(any(row['event']=='condition-blocked' and row.get('stage')=='dim' for row in logs))

    def test_unsaved_draft_does_not_affect_runtime(self):
        """Draft changes do not affect runtime inhibitor decisions until apply."""
        (self.root/'audio').write_text('Sink Input #1\nmedia.class = "Stream/Output/Audio"\nCorked: no\nMute: no\napplication.process.binary = "zen-bin"\n')
        self.ipc('draftPolicy','inhibitOnAudio','true')
        time.sleep(.2)
        state = self.wait(lambda s:s['customInhibit']['known'])
        self.assertFalse(state['customInhibit']['audioPolicyEnabled'])
        self.assertFalse(state['customInhibit']['audio'])
        self.force('dim')
        self.wait(lambda s:s['dim']['applied'] and not s['dim']['pending'])
        self.ipc('resume','dim')
        self.wait(lambda s:not s['dim']['applied'])
        self.ipc('applySettings')
        self.wait(lambda s:s['customInhibit']['known'] and s['customInhibit']['audioPolicyEnabled'] and s['customInhibit']['audio'])
        self.force('dim')
        self.wait(lambda s:s['dim']['pending'])
        self.ipc('draftPolicy','inhibitOnAudio','false')
        time.sleep(.2)
        self.assertTrue(self.state()['customInhibit']['audioPolicyEnabled'])
        self.assertTrue(self.state()['customInhibit']['audio'])
        self.ipc('applySettings')
        self.wait(lambda s:s['customInhibit']['known'] and not s['customInhibit']['audioPolicyEnabled'] and not s['customInhibit']['audio'])
        self.wait(lambda s:s['dim']['applied'] and not s['dim']['pending'])

    def test_failed_lock_request_cannot_suspend(self):
        """An explicit native lock failure never invokes the power command."""
        self.ipc('lockFailure','true')
        self.ipc('deadline','100')
        self.force('suspend')
        state=self.wait(lambda s:'Idle suspend canceled' in s['error'])
        self.assertFalse(state['locked'])
        self.assertFalse(self.actions('suspend'))

    def test_old_secure_condition_cannot_authorize_a_new_suspend(self):
        """Activity invalidates a captured allow result before a later suspend request."""
        (self.bin/'idle_inhibit.sh').write_text('''#!/usr/bin/env python3
import os, sys, time
from pathlib import Path
root=Path(os.environ['HAKUSPACE_IDLE_TEST_ROOT'])
if sys.argv[1]=='--status-json':
    print('{"manual":false,"audio":false,"inhibited":false}')
    raise SystemExit(0)
counter=root/'condition-count'
count=int(counter.read_text())+1 if counter.exists() else 1
temporary=counter.with_suffix('.'+str(os.getpid()))
temporary.write_text(str(count))
temporary.replace(counter)
if count==2:
    (root/'condition-captured').touch()
    deadline=time.monotonic()+5
    while (root/'gate-condition').exists():
        if time.monotonic()>deadline: raise SystemExit(2)
        time.sleep(.01)
raise SystemExit(1 if count>=4 else 0)
''')
        self.fault('gate-condition')
        self.ipc('secure','true')
        self.force('suspend')
        self.wait(lambda s:s['checkingSuspend'] and (self.root/'condition-captured').exists())
        self.ipc('resume','suspend')
        self.force('suspend')
        self.wait(lambda s:s['suspend']['applied'])
        self.fault('gate-condition',False)
        self.wait(lambda s:int((self.root/'condition-count').read_text())>=4 and s['suspend']['pending'])
        self.assertFalse(self.actions('suspend'))

    def test_reload_fences_old_cleanup_and_preserves_lock(self):
        """New ownership survives old destruction callbacks while lock state stays authoritative."""
        for stage in (None,'dim','displayOff'):
            with self.subTest(stage=stage):
                if stage:
                    self.force(stage)
                    self.wait(lambda s:s[stage]['applied'] and not s['mutating'])
                before=self.state()
                self.ipc('reload')
                self.wait(lambda s:s['token']!=before['token'] and s['ready'])
                self.force('displayOff')
                self.wait(lambda s:s['displayOff']['applied'] and not s['mutating'])
                count=len(self.actions('on'))
                time.sleep(.1)
                self.assertEqual(len(self.actions('on')),count)
                self.ipc('resume','displayOff')
                self.wait(lambda s:not s['mutating'] and not s['cleanupRequired'])
        self.force('lock')
        self.wait(lambda s:s['locked'])
        token=self.state()['token']
        self.ipc('reload')
        self.wait(lambda s:s['token']!=token and s['ready'] and s['locked'])


if __name__ == '__main__':
    unittest.main()
