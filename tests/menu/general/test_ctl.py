#!/usr/bin/env python3
"""Exercise General menu storage, stable-ID dispatch and the Classic adapter."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

# Import the production backend without writing artifacts into deployable directories.
ROOT = Path(__file__).resolve().parents[3]
BACKEND = ROOT / 'src/core/backend/user/general_menu_ctl.py'
ADAPTER = ROOT / 'src/core/menu/hm_general.sh'
sys.path.insert(0, str(BACKEND.parent))
spec = importlib.util.spec_from_file_location('general_menu', BACKEND)
ctl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ctl)


class GeneralMenuTests(unittest.TestCase):
    """Keep every config, launched fixture and installer operation in a disposable HOME."""

    def setUp(self):
        """Seed the real template and isolate backend path overrides."""
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.path = self.home / 'hakucfg/config/hakumenu-general.json'
        self.path.parent.mkdir(parents=True)
        self.path.write_bytes((ROOT / 'src/home/hakucfg/config/hakumenu-general.json').read_bytes())
        self.environment = patch.dict(os.environ, {'HOME': str(self.home), 'HAKUSPACE_GENERAL_MENU_FILE': str(self.path)})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def cli(self, *arguments, success=True, environment=None):
        """Exercise the public CLI and require a single structured JSON response."""
        result = subprocess.run([sys.executable, str(BACKEND), *arguments], capture_output=True,
                                text=True, env=environment)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        model = json.loads(result.stdout)
        self.assertEqual(model['ok'], success)
        return model

    def recorder(self, name):
        """Create an executable that records arguments instead of launching desktop tools."""
        executable = self.home / (name + '.py')
        output = self.home / (name + '.json')
        executable.write_text(f'#!{sys.executable}\nimport json,sys\nfrom pathlib import Path\n'
                              f'Path({str(output)!r}).write_text(json.dumps(sys.argv[1:]))\n')
        executable.chmod(0o700)
        return executable, output

    def await_output(self, output):
        """Wait briefly for a detached fixture to finish its bounded write."""
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            try:
                return json.loads(output.read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                time.sleep(0.01)
        self.fail(f'No completed launch output at {output}')

    def test_snapshot_order_unicode_and_capabilities(self):
        """Expose seeded user data before the five immutable built-ins."""
        model = self.cli('list')
        self.assertEqual(model['schemaVersion'], 1)
        self.assertEqual(len(model['items']), 7)
        self.assertEqual(model['items'][2]['icon'], '')
        self.assertEqual(model['items'][0]['id'], 'app-menu')
        self.assertEqual(model['items'][-1]['id'], 'quit')
        self.assertFalse(any(row['id'].startswith(('static-', 'builtin-')) for row in model['items']))
        for row in model['items']:
            self.assertTrue(row['mutable'])
            self.assertEqual(row['origin'], 'user')
            self.assertTrue(row['enabled'])
        self.assertEqual(self.cli('get', 'browser')['item']['label'], 'Browser')
        self.assertEqual(self.cli('check')['revision'], model['revision'])

    def test_crud_and_persistent_order(self):
        """Preserve IDs, insertion positions and reordered data across fresh processes."""
        initial = self.cli('list')
        created = self.cli('add', json.dumps({'label': '日本語 Browser', 'icon': '󰈹',
            'commandText': 'printf "two words"', 'afterId': 'browser', 'expectedRevision': initial['revision']}))
        row = created['items'][3]
        identity = row['id']
        self.assertTrue(identity.startswith('user-'))
        self.assertEqual(row['argv'], ['printf', 'two words'])
        edited = self.cli('update', identity, '{"label":"Renamed"}', '--expected-revision', created['revision'])
        self.assertEqual(edited['items'][3]['id'], identity)
        self.assertEqual(edited['items'][3]['label'], 'Renamed')
        self.cli('move', identity, '0', '--expected-revision', edited['revision'])
        self.assertEqual(self.cli('list')['items'][0]['id'], identity)
        self.cli('remove', identity)
        self.assertNotIn(identity, [row['id'] for row in self.cli('list')['items']])
        self.assertEqual(self.cli('list')['items'][0]['id'], 'app-menu')

    def test_duplicate_labels_dispatch_by_id(self):
        """Identical display labels must launch different explicit commands."""
        for identity in ('first', 'second'):
            executable, output = self.recorder(identity)
            self.cli('add', json.dumps({'id': identity, 'label': 'Browser', 'argv': [str(executable), identity]}))
            self.cli('run', identity)
            self.assertEqual(self.await_output(output), [identity])

    def test_shlex_quotes_and_shell_operators_are_literal(self):
        """Parse quoted words and pass operators as arguments without invoking a shell."""
        executable, output = self.recorder('words')
        sentinel = self.home / 'must-not-exist'
        command = f'{executable} "two words" "a\\\"b" ; touch {sentinel} | cat && echo $(id)'
        self.cli('add', json.dumps({'id': 'words', 'label': 'Words', 'commandText': command}))
        self.cli('run', 'words')
        arguments = self.await_output(output)
        self.assertEqual(arguments[:2], ['two words', 'a"b'])
        self.assertIn(';', arguments)
        self.assertIn('$(id)', arguments)
        self.assertFalse(sentinel.exists())

    def test_launch_contract_and_home_expansion(self):
        """Custom actions use detached argv execution and tilde resolves to HOME."""
        with patch.object(ctl.subprocess, 'Popen') as launch:
            ctl.run('run', 'browser')
            arguments, options = launch.call_args
            self.assertEqual(arguments[0], ['open_browser.sh'])
            self.assertNotIn('shell', options)
            self.assertTrue(options['start_new_session'])
            self.assertTrue(options['close_fds'])
            ctl.run('run', 'file-manager')
            self.assertEqual(launch.call_args.args[0], ['xdg-open', str(self.home)])

    def test_static_ids_are_unknown_and_identity_changes_are_rejected(self):
        """Static shell controls are outside the custom backend and IDs cannot be rewritten."""
        before = self.path.read_bytes()
        for args in [('update', 'static-wifi', '{"label":"Other"}'), ('remove', 'static-wifi'),
                     ('move', 'static-wifi', '0'), ('get', 'static-wifi'), ('run', 'static-wifi'),
                     ('get', 'builtin-wifi'), ('run', 'builtin-wifi'), ('update', 'browser', '{"id":"other"}')]:
            self.cli(*args, success=False)
            self.assertEqual(self.path.read_bytes(), before)

    def test_revision_conflict_preserves_external_edit(self):
        """Reject stale mutations after an editor changes the file, including whitespace."""
        revision = self.cli('list')['revision']
        self.path.write_bytes(self.path.read_bytes() + b'\n')
        external = self.path.read_bytes()
        for args in [('add', '{"label":"X","argv":["true"]}'), ('update', 'browser', '{"label":"X"}'),
                     ('remove', 'browser'), ('move', 'browser', '0')]:
            self.assertEqual(self.cli(*args, '--expected-revision', revision, success=False)['error'], 'conflict')
            self.assertEqual(self.path.read_bytes(), external)

    def test_parallel_writers_use_the_same_revision(self):
        """Only one concurrent mutation can consume a given revision."""
        revision = self.cli('list')['revision']
        arguments = [sys.executable, str(BACKEND), 'add', '{"label":"X","argv":["true"]}',
                     '--expected-revision', revision]
        children = [subprocess.Popen(arguments, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
        results = [json.loads(child.communicate(timeout=5)[0]) for child in children]
        self.assertEqual(sum(result['ok'] for result in results), 1)
        self.assertEqual(next(result['error'] for result in results if not result['ok']), 'conflict')

    def test_failed_replace_keeps_original_and_cleans_temp_file(self):
        """Leave the previous complete file intact when atomic replacement fails."""
        original = self.path.read_bytes()
        with patch.object(ctl.os, 'replace', side_effect=OSError('simulated failed write')):
            with self.assertRaises(OSError):
                ctl.run('remove', 'browser')
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(list(self.path.parent.glob('.general-menu-*')), [])

    def test_fsync_failure_before_replace_keeps_original(self):
        """Do not replace data before the temporary file reaches durable storage."""
        original = self.path.read_bytes()
        with patch.object(ctl.os, 'fsync', side_effect=OSError('simulated fsync failure')):
            with self.assertRaises(OSError):
                ctl.run('remove', 'browser')
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(list(self.path.parent.glob('.general-menu-*')), [])

    def test_edit_during_write_is_detected(self):
        """Recheck file bytes after preparing the temporary replacement."""
        fsync = ctl.os.fsync
        external = self.path.read_bytes() + b'\n'

        def editor(fd):
            """Simulate an external editor saving while the backend flushes its temp file."""
            self.path.write_bytes(external)
            return fsync(fd)

        with patch.object(ctl.os, 'fsync', side_effect=editor):
            with self.assertRaisesRegex(ValueError, 'conflict'):
                ctl.run('remove', 'browser')
        self.assertEqual(self.path.read_bytes(), external)

    def test_permission_edit_during_write_is_detected(self):
        """Do not restore group-readable permissions after an external chmod makes data private."""
        self.path.chmod(0o640)
        fsync = ctl.os.fsync
        original = self.path.read_bytes()

        def tighten_permissions(fd):
            """Change permissions while the backend flushes its temporary document."""
            self.path.chmod(0o600)
            return fsync(fd)

        with patch.object(ctl.os, 'fsync', side_effect=tighten_permissions):
            with self.assertRaisesRegex(ValueError, 'conflict'):
                ctl.run('remove', 'browser')
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o600)

    def test_malformed_file_is_never_overwritten(self):
        """Invalid documents remain available for manual recovery."""
        for raw in ('{broken', '{"schemaVersion":1,"schemaVersion":1,"items":[]}',
                    '{"schemaVersion":2,"items":[]}', '{"schemaVersion":true,"items":[]}'):
            self.path.write_text(raw)
            self.cli('remove', 'browser', success=False)
            self.assertEqual(self.path.read_text(), raw)

    def test_symlink_file_parent_and_nonregular_file_are_rejected(self):
        """Refuse both config symlinks and directory redirects without touching their targets."""
        original = self.path.read_bytes()
        outside = self.home / 'outside.json'
        outside.write_bytes(original)
        self.path.unlink()
        self.path.symlink_to(outside)
        self.cli('list', success=False)
        self.cli('remove', 'browser', success=False)
        self.assertEqual(outside.read_bytes(), original)
        self.path.unlink()
        os.mkfifo(self.path)
        self.cli('list', success=False)
        self.path.unlink()
        self.path.parent.rmdir()
        self.path.parent.symlink_to(self.home, target_is_directory=True)
        self.cli('list', success=False)
        self.assertFalse((self.home / self.path.name).exists())

    def test_invalid_payloads_do_not_modify_document(self):
        """Enforce the schema and bounds at the mutation boundary."""
        original = self.path.read_bytes()
        valid = {'id': 'new', 'label': 'New', 'argv': ['true']}
        invalid = [
            {'id': 'builtin-new'}, {'id': 'static-new'}, {'id': 'browser'}, {'id': 'bad id'}, {'label': ''}, {'label': ' '},
            {'label': 'x' * 97}, {'icon': 'x' * 17}, {'label': 'line\nbreak'}, {'icon': '\x1f'},
            {'argv': []}, {'argv': ['']}, {'argv': [1]}, {'argv': ['a\0b']}, {'argv': ['x' * 4097]},
            {'argv': ['x'] * 129}, {'enabled': 1}, {'unknown': True}, {'afterId': 'missing'},
            {'commandText': 'true'},
        ]
        for fields in invalid:
            with self.subTest(fields=fields):
                self.cli('add', json.dumps({**valid, **fields}), success=False)
                self.assertEqual(self.path.read_bytes(), original)
        self.cli('update', 'browser', '{"commandText":"unclosed \\\""}', success=False)
        self.cli('move', 'browser', '-1', success=False)
        self.cli('move', 'browser', '128', success=False)
        self.assertEqual(self.path.read_bytes(), original)

    def test_duplicate_ids_and_item_count_and_size_limits(self):
        """Bound stored documents and reject ambiguous identities."""
        document = json.loads(self.path.read_text())
        document['items'].append(copy.deepcopy(document['items'][0]))
        self.path.write_text(json.dumps(document))
        self.cli('check', success=False)
        document['items'] = [{'id': f'row-{i}', 'label': 'X', 'argv': ['true']} for i in range(128)]
        self.path.write_text(json.dumps(document))
        self.cli('add', '{"label":"Overflow","argv":["true"]}', success=False)
        document['items'].append({'id': 'row-129', 'label': 'X', 'argv': ['true']})
        self.path.write_text(json.dumps(document))
        self.cli('check', success=False)
        self.path.write_bytes(b' ' * (ctl.MAX_BYTES + 1))
        self.cli('check', success=False)
        with self.assertRaises(ValueError):
            ctl.parse(' ' * (ctl.MAX_BYTES + 1))

    def test_missing_unknown_disabled_and_failed_launch(self):
        """Report invalid launches without falling back to text matching."""
        self.cli('run', 'unknown', success=False)
        self.cli('update', 'browser', '{"enabled":false}')
        self.cli('run', 'browser', success=False)
        self.cli('add', '{"id":"missing","label":"Missing","argv":["/no/such/executable"]}')
        self.cli('run', 'missing', success=False)
        self.path.unlink()
        self.cli('list', success=False)
        self.assertFalse(self.path.exists())

    def test_rofi_metadata_and_selection_ignore_display_text(self):
        """Rofi emits stable IDs and dispatches solely through ROFI_INFO."""
        initial = subprocess.run(['bash', str(ADAPTER)], capture_output=True, text=True,
                                 env={**os.environ, 'ROFI_RETV': '0'})
        self.assertEqual(initial.returncode, 0, initial.stderr)
        self.assertEqual(len([line for line in initial.stdout.splitlines() if not line.startswith('\0')]), 7)
        executable, output = self.recorder('rofi')
        self.cli('add', json.dumps({'id': 'rofi-fixture', 'label': 'Browser', 'argv': [str(executable)]}))
        result = subprocess.run(['bash', str(ADAPTER)], capture_output=True, text=True,
                                env={**os.environ, 'ROFI_RETV': '0', 'ROFI_INFO': 'stale'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('  Browser\0info\x1fbrowser\n', result.stdout)
        self.assertIn('  App Menu\0info\x1fapp-menu\n', result.stdout)
        self.assertNotIn('Wifi', result.stdout)
        self.assertNotIn('Bluetooth', result.stdout)
        self.assertEqual(len([line for line in result.stdout.splitlines() if not line.startswith('\0')]), 8)
        self.assertIn('  Browser\0info\x1frofi-fixture\n', result.stdout)
        self.assertIn('\0no-custom\x1ftrue\n', result.stdout)
        for retv in ('2', '3'):
            subprocess.run(['bash', str(ADAPTER), 'Browser'], check=True,
                           env={**os.environ, 'ROFI_RETV': retv, 'ROFI_INFO': 'rofi-fixture'})
            self.assertFalse(output.exists())
        subprocess.run(['bash', str(ADAPTER), 'Entirely different display text'], check=True,
                       env={**os.environ, 'ROFI_RETV': '1', 'ROFI_INFO': 'rofi-fixture'})
        self.assertEqual(self.await_output(output), [])

    def test_rofi_dispatches_updated_command_and_removes_deleted_row(self):
        """Classic immediately observes custom label, command and removal edits."""
        executable, output = self.recorder('edited')
        self.cli('add', json.dumps({'id': 'edited', 'label': 'Before', 'argv': ['false']}))
        self.cli('update', 'edited', json.dumps({'label': 'After', 'argv': [str(executable), 'updated command']}))
        rendered = subprocess.run(['bash', str(ADAPTER)], capture_output=True, text=True,
                                  env={**os.environ, 'ROFI_RETV': '0'}, check=True)
        self.assertIn('After\0info\x1fedited\n', rendered.stdout)
        subprocess.run(['bash', str(ADAPTER), 'Before'], check=True,
                       env={**os.environ, 'ROFI_RETV': '1', 'ROFI_INFO': 'edited'})
        self.assertEqual(self.await_output(output), ['updated command'])
        self.cli('remove', 'edited')
        rendered = subprocess.run(['bash', str(ADAPTER)], capture_output=True, text=True,
                                  env={**os.environ, 'ROFI_RETV': '0'}, check=True)
        self.assertNotIn('\0info\x1fedited\n', rendered.stdout)

    def test_flat_installation_resolves_adapter_and_backend(self):
        """Keep the public entrypoint working after deployment flattens script paths."""
        binary = self.home / '.local/bin'
        binary.mkdir(parents=True)
        for source in (ADAPTER, ROOT / 'src/core/frontend/classic/hm_general_rofi.py', BACKEND,
                       BACKEND.with_name('hikai_settings_ctl.py')):
            (binary / source.name).symlink_to(source)
        result = subprocess.run(['bash', str(binary / ADAPTER.name)], capture_output=True, text=True,
                                env={**os.environ, 'ROFI_RETV': '0'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('\0info\x1fbrowser\n', result.stdout)

    def test_mutation_retains_private_permissions(self):
        """Do not make a private command document readable by other users."""
        self.path.chmod(0o600)
        self.cli('update', 'browser', '{"label":"Web"}')
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o600)


if __name__ == '__main__':
    unittest.main()
