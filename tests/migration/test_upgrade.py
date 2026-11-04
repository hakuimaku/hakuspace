#!/usr/bin/env python3
"""Exercise upgrade boundaries with private homes and package-manager doubles."""
import io
import json
import os
from pathlib import Path
import py_compile
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class UpgradeTests(unittest.TestCase):
    # Keep every deployment and external command under a disposable HOME.
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix='hakuspace-upgrade-')
        self.addCleanup(self.work.cleanup)
        self.home = Path(self.work.name)
        self.repo = self.home / 'repo'
        shutil.copytree(ROOT / 'scripts', self.repo / 'scripts')
        shutil.copytree(ROOT / 'src/core', self.repo / 'src/core', ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copytree(ROOT / 'src/packages', self.repo / 'src/packages')
        shutil.copytree(ROOT / 'src/home/hakucfg', self.repo / 'src/home/hakucfg')
        self.mock = self.home / 'mock'
        self.mock.mkdir()
        self.bin = self.home / '.local/bin'
        self.bin.mkdir(parents=True)
        self.env = dict(os.environ, HOME=str(self.home), HAKU_DIR=str(self.repo),
                        XDG_STATE_HOME=str(self.home / '.local/state'),
                        BACKUP_DIR=str(self.home / 'backup'), PATH=str(self.mock) + ':' + os.environ['PATH'],
                        PYTHONDONTWRITEBYTECODE='1')
        for name in ('pacman', 'quickshell'):
            self.command(name, 'exit 0\n')
        self.receipt = self.home / '.local/state/hakuspace/migrations/v26.11.json'

    # Build executable command doubles without invoking system package changes.
    def command(self, name, body):
        path = self.mock / name
        path.write_text('#!/bin/bash\n' + body)
        path.chmod(0o755)

    # Run production modules and include their diagnostics in assertion failures.
    def run_script(self, name, *args, ok=True):
        result = subprocess.run(['bash', str(self.repo / 'scripts' / name), *args],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    # Use the shipped legacy menu without ever invoking it.
    def legacy_menu(self):
        path = self.home / 'hakucfg/general-menu.sh'
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(subprocess.check_output(['git', '-C', str(ROOT), 'show',
                         'v26.10-1:src/home/hakucfg/general-menu.sh']))
        return path

    def test_tagged_snapshot_upgrade_preserves_custom_menu_in_both_deploy_modes(self):
        """Upgrade real v26.10-1 files without rewriting later customizations."""
        archive = subprocess.check_output(['git', '-C', str(ROOT), 'archive', 'v26.10-1',
                                           'src/core', 'src/home/hakucfg'])
        for mode in ('symlink', 'copy'):
            with self.subTest(mode=mode):
                home = self.home / mode
                repo = home / 'repo'
                repo.mkdir(parents=True)
                with tarfile.open(fileobj=io.BytesIO(archive)) as snapshot:
                    snapshot.extractall(repo, filter='data')
                binary = home / '.local/bin'
                binary.mkdir(parents=True)
                for source in (repo / 'src/core').rglob('*'):
                    if not source.is_file() or source.name == 'README.md':
                        continue
                    destination = binary / source.name
                    if mode == 'symlink':
                        destination.symlink_to(source)
                    else:
                        shutil.copy2(source, destination)
                shutil.copytree(repo / 'src/home/hakucfg', home / 'hakucfg')
                legacy = home / 'hakucfg/general-menu.sh'
                legacy.write_text(legacy.read_text().replace('\nEOF', '\nCustom Action\nEOF', 1)
                                  .replace('\nesac', '\n    *"Custom Action"*) spawn code --new-window ;;\nesac', 1))
                original = legacy.read_bytes()
                custom = binary / 'personal-command'
                custom.write_text('personal data')

                # Replace only the disposable checkout to model the Git update.
                shutil.rmtree(repo / 'src')
                shutil.copytree(ROOT / 'src/core', repo / 'src/core', ignore=shutil.ignore_patterns('__pycache__'))
                shutil.copytree(ROOT / 'src/home/hakucfg', repo / 'src/home/hakucfg')
                shutil.copytree(ROOT / 'scripts', repo / 'scripts', ignore=shutil.ignore_patterns('__pycache__'))
                environment = dict(self.env, HOME=str(home), HAKU_DIR=str(repo),
                                   XDG_STATE_HOME=str(home / '.local/state'), BACKUP_DIR=str(home / 'backup'))

                def run(name, *arguments):
                    """Run real deployment modules against the archived private installation."""
                    result = subprocess.run(['bash', str(repo / 'scripts' / name), *arguments],
                                            env=environment, capture_output=True, text=True, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    return result

                run('migrate.sh', '--plan')
                run('core.sh', '--mode', mode)
                run('migrate.sh', '--apply')
                run('migrate.sh', '--complete')
                menu = home / 'hakucfg/config/hakumenu-general.json'
                document = json.loads(menu.read_text())
                rows = document['items']
                self.assertEqual(len(rows), 8)
                self.assertEqual(len({row['id'] for row in rows}), 8)
                self.assertEqual(sum(row['id'] == 'app-menu' for row in rows), 1)
                self.assertEqual(rows[-1]['argv'], ['code', '--new-window'])
                rows[-1]['label'] = 'Edited after upgrade'
                menu.write_text(json.dumps(document))
                edited = menu.read_bytes()
                run('core.sh', '--mode', mode)
                run('migrate.sh', '--apply')
                run('migrate.sh', '--complete')
                run('migrate.sh', '--audit')
                status = json.loads(run('migrate.sh', '--status').stdout)
                self.assertTrue(status['completion_eligible'])
                self.assertEqual(menu.read_bytes(), edited)
                self.assertEqual(legacy.read_bytes(), original)
                self.assertEqual(custom.read_text(), 'personal data')

    # Inject crashes inside the real migrator without adding production fault switches.
    def fault_migration(self, fault):
        code = '''import importlib.util, os, signal, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location('migration', os.environ['HAKU_DIR'] + '/scripts/migrate.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
''' + fault + '''
sys.argv = ['migrate.py', '--apply']
sys.exit(module.main())
'''
        return subprocess.run(['python3', '-B', '-c', code], env=self.env,
                              text=True, capture_output=True)

    def test_applied_receipt_requires_a_valid_current_destination(self):
        legacy = self.legacy_menu()
        original_legacy = legacy.read_bytes()
        self.run_script('migrate.sh', '--apply')
        self.run_script('migrate.sh', '--complete')
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        valid = destination.read_bytes()
        applied = self.receipt.read_bytes()
        for raw, status in ((None, 'missing'), (b'{broken', 'malformed'),
                            (b'{"schemaVersion":9,"items":[]}', 'schema-invalid'),
                            (b'{"schemaVersion":1,"items":[],"items":[]}', 'invalid')):
            with self.subTest(status=status):
                self.receipt.write_bytes(applied)
                if raw is None:
                    destination.unlink(missing_ok=True)
                else:
                    destination.write_bytes(raw)
                state = json.loads(self.run_script('migrate.sh', '--status').stdout)
                self.assertEqual(state['steps']['v26.11-menu']['status'], 'applied')
                self.assertEqual(state['menu_destination']['status'], status)
                self.assertFalse(state['completion_eligible'])
                self.run_script('migrate.sh', '--plan', ok=False)
                self.assertEqual(self.receipt.read_bytes(), applied)
                result = self.run_script('migrate.sh', '--complete', ok=False)
                self.assertIn(str(destination), result.stdout + result.stderr)
                self.run_script('migrate.sh', '--apply', ok=False)
                receipt = json.loads(self.receipt.read_text())
                self.assertEqual(receipt['status'], 'failed')
                self.assertEqual(receipt['steps']['v26.11-menu']['status'], 'applied')
                self.assertEqual(destination.read_bytes() if destination.exists() else None, raw)
                self.assertEqual(legacy.read_bytes(), original_legacy)
                document = json.loads(valid)
                document['items'][1]['label'] = 'Manually repaired launcher'
                destination.write_text(json.dumps(document))
                repaired = destination.read_bytes()
                self.run_script('migrate.sh', '--apply')
                self.run_script('migrate.sh', '--complete')
                self.assertEqual(destination.read_bytes(), repaired)
                self.assertTrue(json.loads(self.run_script('migrate.sh', '--status').stdout)['completion_eligible'])

    def test_strict_json_validation_preserves_invalid_input_and_allows_retry(self):
        legacy = self.legacy_menu()
        original = legacy.read_bytes()
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        destination.parent.mkdir()
        for raw, reason in (
            ('{"schemaVersion":1,"items":[],"items":[]}', 'duplicate JSON key: items'),
            ('{"schemaVersion":1,"items":[{"id":"custom","label":"first","label":"last","argv":["true"]}]}',
             'duplicate JSON key: label'),
            ('{"schemaVersion":1,"items":"invalid"}', 'items must be an array'),
        ):
            with self.subTest(reason=reason):
                self.receipt.unlink(missing_ok=True)
                destination.write_text(raw)
                result = self.run_script('migrate.sh', '--apply', ok=False)
                self.assertIn(reason, result.stdout + result.stderr)
                self.assertIn(str(destination), result.stdout + result.stderr)
                self.assertEqual(destination.read_text(), raw)
                self.assertEqual(legacy.read_bytes(), original)
                self.run_script('migrate.sh', '--complete', ok=False)
                destination.write_bytes((self.repo / 'src/home/hakucfg/config/hakumenu-general.json').read_bytes())
                self.run_script('migrate.sh', '--apply')
                self.run_script('migrate.sh', '--complete')

    def test_external_and_explicit_xdg_state_remain_read_only_until_apply(self):
        legacy = self.legacy_menu()
        external = tempfile.TemporaryDirectory(prefix='hakuspace-external-state-')
        self.addCleanup(external.cleanup)
        for root in (self.home / 'explicit-state', Path(external.name) / 'state'):
            with self.subTest(root=str(root)):
                root.mkdir()
                unrelated = root / 'unrelated'
                unrelated.write_text('keep')
                self.env['XDG_STATE_HOME'] = str(root)
                self.run_script('migrate.sh', '--plan')
                self.run_script('migrate.sh', '--status')
                self.assertEqual(list(root.iterdir()), [unrelated])
                self.run_script('migrate.sh', '--apply')
                self.run_script('migrate.sh', '--complete')
                self.run_script('migrate.sh', '--apply')
                self.run_script('migrate.sh', '--complete')
                receipt = root / 'hakuspace/migrations/v26.11.json'
                self.assertEqual(json.loads(receipt.read_text())['status'], 'applied')
                self.assertEqual(unrelated.read_text(), 'keep')
                self.assertTrue(legacy.is_file())

    def test_unset_and_empty_xdg_state_use_the_default(self):
        self.legacy_menu()
        for value in (None, ''):
            if value is None:
                self.env.pop('XDG_STATE_HOME')
            else:
                self.env['XDG_STATE_HOME'] = value
            self.run_script('migrate.sh', '--apply')
            self.run_script('migrate.sh', '--complete')
            self.assertEqual(json.loads(self.receipt.read_text())['status'], 'applied')

    def test_state_namespace_and_receipt_symlinks_are_preserved(self):
        root = self.home / 'private-state'
        root.mkdir()
        target = self.home / 'unrelated-state'
        target.mkdir()
        self.env['XDG_STATE_HOME'] = str(root)
        namespace = root / 'hakuspace'
        namespace.symlink_to(target, target_is_directory=True)
        self.run_script('migrate.sh', '--apply', ok=False)
        self.assertEqual(list(target.iterdir()), [])
        namespace.unlink()
        migrations = namespace / 'migrations'
        migrations.mkdir(parents=True)
        unrelated = target / 'user.json'
        unrelated.write_text('{"keep":true}')
        receipt = migrations / 'v26.11.json'
        receipt.symlink_to(unrelated)
        for mode in ('--plan', '--status', '--apply', '--complete'):
            self.run_script('migrate.sh', mode, ok=False)
        self.assertTrue(receipt.is_symlink())
        self.assertEqual(unrelated.read_text(), '{"keep":true}')

    def test_custom_json_conflict_is_preserved_until_manual_reconciliation(self):
        legacy = self.legacy_menu()
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        destination.parent.mkdir()
        destination.write_text(json.dumps({'schemaVersion': 1, 'items': [
            {'id': 'my-custom-action', 'label': 'My Action', 'argv': ['code', '--new-window']}]}))
        custom = destination.read_bytes()
        self.run_script('migrate.sh', '--apply', ok=False)
        self.assertEqual(destination.read_bytes(), custom)
        # Retiring the retained legacy input is an explicit manual choice, not automatic repair.
        legacy.rename(legacy.with_suffix('.sh.saved'))
        self.run_script('migrate.sh', '--apply')
        self.run_script('migrate.sh', '--complete')
        self.assertEqual(destination.read_bytes(), custom)

    def test_applied_destination_symlink_cannot_complete(self):
        self.legacy_menu()
        self.run_script('migrate.sh', '--apply')
        self.run_script('migrate.sh', '--complete')
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        saved = self.home / 'saved-menu.json'
        destination.rename(saved)
        original = saved.read_bytes()
        destination.symlink_to(saved)
        self.run_script('migrate.sh', '--complete', ok=False)
        self.run_script('migrate.sh', '--apply', ok=False)
        self.assertTrue(destination.is_symlink())
        self.assertEqual(saved.read_bytes(), original)
        destination.unlink()
        destination.write_bytes(original)
        self.run_script('migrate.sh', '--complete')

    def test_duplicate_receipt_keys_are_not_silently_discarded(self):
        self.receipt.parent.mkdir(parents=True)
        raw = '{"target_version":"v26.11","status":"pending","status":"applied","steps":{}}'
        self.receipt.write_text(raw)
        result = self.run_script('migrate.sh', '--status', ok=False)
        self.assertIn('duplicate JSON key: status', result.stderr)
        self.assertIn(str(self.receipt), result.stderr)
        self.assertEqual(self.receipt.read_text(), raw)

    def test_destination_edit_during_backup_is_preserved(self):
        self.legacy_menu()
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        destination.parent.mkdir()
        destination.write_bytes((self.repo / 'src/home/hakucfg/config/hakumenu-general.json').read_bytes())
        result = self.fault_migration('''
original = module.backup
def edit_during_backup(path):
    original(path)
    if path.name == 'general-menu.sh':
        import json
        document = json.loads(module.MENU.read_text())
        document['items'][0]['label'] = 'Edited during migration'
        module.MENU.write_text(json.dumps(document))
module.backup = edit_during_backup
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('destination changed during migration', result.stdout + result.stderr)
        self.assertEqual(json.loads(destination.read_text())['items'][0]['label'], 'Edited during migration')

    def test_unsafe_state_paths_are_rejected_without_traversal(self):
        target = self.home / 'state-target'
        target.mkdir()
        link = self.home / 'linked-state'
        link.symlink_to(target, target_is_directory=True)
        shared = self.home / 'shared-state'
        shared.mkdir(mode=0o777)
        shared.chmod(0o777)
        regular = self.home / 'state-is-a-file'
        regular.write_text('keep')
        for path in ('relative-state', str(self.home / '..' / 'escape-state'), str(link), str(shared), str(regular)):
            with self.subTest(path=path):
                self.env['XDG_STATE_HOME'] = path
                for mode in ('--plan', '--status', '--apply', '--complete'):
                    self.run_script('migrate.sh', mode, ok=False)
        self.assertEqual(list(target.iterdir()), [])
        self.assertEqual(list(shared.iterdir()), [])
        readonly = self.home / 'readonly-state'
        readonly.mkdir(mode=0o500)
        self.addCleanup(readonly.chmod, 0o700)
        self.env['XDG_STATE_HOME'] = str(readonly)
        self.run_script('migrate.sh', '--apply', ok=False)
        self.assertEqual(list(readonly.iterdir()), [])

    def test_backup_path_cannot_escape_home_through_dotdot(self):
        legacy = self.legacy_menu()
        external = tempfile.TemporaryDirectory(prefix='hakuspace-unsafe-backup-')
        self.addCleanup(external.cleanup)
        self.env['BACKUP_DIR'] = str(self.home / '..' / Path(external.name).name)
        self.run_script('migrate.sh', '--apply', ok=False)
        self.assertTrue(legacy.is_file())
        self.assertEqual(list(Path(external.name).iterdir()), [])

    def test_partial_backup_failure_leaves_no_corrupt_backup(self):
        legacy = self.legacy_menu()
        result = self.fault_migration('''
def fail_copy(source, target, *args, **kwargs):
    Path(target).write_bytes(b'partial backup')
    raise OSError('injected backup copy failure')
module.shutil.copy2 = fail_copy
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'backup/hakucfg/general-menu.sh').exists())
        self.assertTrue(legacy.is_file())
        self.run_script('migrate.sh', '--apply')
        self.run_script('migrate.sh', '--complete')
        self.assertEqual((self.home / 'backup/hakucfg/general-menu.sh').read_bytes(), legacy.read_bytes())

    def test_backup_directories_are_synced_before_cleanup_and_on_retry(self):
        css = self.home / '.config/gtk-3.0/gtk.css'
        css.parent.mkdir(parents=True)
        original = subprocess.check_output(['git', '-C', str(ROOT), 'show',
                                          'v26.10-1:src/home/.config/gtk-3.0/gtk.css'])
        target = self.home / 'backup/.config/gtk-3.0/gtk.css'
        for symlink in (False, True):
            with self.subTest(symlink=symlink):
                if target.exists() or target.is_symlink():
                    target.unlink()
                if symlink:
                    css.symlink_to(self.repo / 'src/home/.config/gtk-3.0/gtk.css')
                else:
                    css.write_bytes(original)
                result = self.fault_migration('''
original_sync = module.os.fsync
def fail_backup_directory_sync(fd):
    path = Path(os.readlink('/proc/self/fd/' + str(fd)))
    if path == module.HOME / 'backup/.config/gtk-3.0':
        raise OSError('injected backup directory fsync failure')
    original_sync(fd)
module.os.fsync = fail_backup_directory_sync
''')
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(css.exists() or css.is_symlink())
                self.assertTrue(target.exists() or target.is_symlink())
                result = self.fault_migration('''
import stat
events = []
original_sync = module.os.fsync
original_unlink = Path.unlink
def record_sync(fd):
    if stat.S_ISDIR(os.fstat(fd).st_mode):
        events.append(str(Path(os.readlink('/proc/self/fd/' + str(fd)))))
    original_sync(fd)
def check_cleanup(path, *args, **kwargs):
    if path == module.HOME / '.config/gtk-3.0/gtk.css':
        for expected in ('backup/.config/gtk-3.0', 'backup/.config', 'backup', '.'):
            assert str(module.HOME / expected) in events, (expected, events)
    return original_unlink(path, *args, **kwargs)
module.os.fsync = record_sync
Path.unlink = check_cleanup
''')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse(css.exists() or css.is_symlink())

    def test_audit_distinguishes_receipt_states_without_writing(self):
        self.run_script('migrate.sh', '--audit')
        self.legacy_menu()
        self.run_script('migrate.sh', '--apply')
        pending = self.receipt.read_bytes()
        result = self.run_script('migrate.sh', '--audit', ok=False)
        self.assertEqual(result.returncode, 3)
        self.assertIn('pending-finalization', result.stdout)
        self.assertEqual(self.receipt.read_bytes(), pending)
        self.run_script('migrate.sh', '--complete')
        applied = self.receipt.read_bytes()
        result = self.run_script('migrate.sh', '--audit')
        self.assertIn('applied', result.stdout)
        for status in ('failed', 'pending'):
            receipt = json.loads(applied)
            receipt['status'] = status
            if status == 'pending':
                receipt['steps'] = {}
            self.receipt.write_text(json.dumps(receipt))
            before = self.receipt.read_bytes()
            result = self.run_script('migrate.sh', '--audit', ok=False)
            self.assertEqual(result.returncode, 1)
            self.assertIn(status, result.stdout + result.stderr)
            self.assertEqual(self.receipt.read_bytes(), before)
        self.receipt.unlink()
        result = self.run_script('migrate.sh', '--audit', ok=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn('unverified', result.stdout)
        self.assertFalse(self.receipt.exists())

    def test_doctor_reports_unverified_and_pending_migration_separately(self):
        self.run_script('core.sh')
        for name in ('state', 'hakucfg'):
            (self.repo / f'scripts/{name}.sh').write_text('#!/bin/bash\nexit 0\n')
        code = f'''source '{self.repo}/scripts/doctor.sh'
registry_get_common_configs() {{ :; }}
run_doctor
'''
        self.legacy_menu()
        self.run_script('migrate.sh', '--apply')
        pending = self.receipt.read_bytes()
        self.receipt.unlink()
        env = dict(self.env, HAKUSPACE_DEPLOY_MODE='symlink')
        for content, message in ((None, 'migration history unverified'), (pending, 'migration pending finalization')):
            if content is not None:
                self.receipt.write_bytes(content)
            result = subprocess.run(['bash', '-c', code], env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(message, result.stdout)
            self.assertNotIn('Everything is in order!', result.stdout)
        self.run_script('migrate.sh', '--complete')
        result = subprocess.run(['bash', '-c', code], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Everything is in order!', result.stdout)

    def test_failure_after_backups_and_during_menu_publish_can_retry(self):
        legacy = self.legacy_menu()
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        for point in ('before-write', 'replace'):
            with self.subTest(point=point):
                destination.unlink(missing_ok=True)
                self.receipt.unlink(missing_ok=True)
                fault = '''
original = module.atomic_json
def fail_write(path, *args, **kwargs):
    if path.name == 'hakumenu-general.json':
        raise OSError('injected after backup failure')
    return original(path, *args, **kwargs)
module.atomic_json = fail_write
''' if point == 'before-write' else '''
original = module.os.replace
def fail_replace(source, target, *args, **kwargs):
    if Path(target).name == 'hakumenu-general.json':
        raise OSError('injected publish failure')
    return original(source, target, *args, **kwargs)
module.os.replace = fail_replace
'''
                result = self.fault_migration(fault)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(destination.exists())
                self.assertEqual((self.home / 'backup/hakucfg/general-menu.sh').read_bytes(), legacy.read_bytes())
                self.run_script('migrate.sh', '--apply')
                self.run_script('migrate.sh', '--complete')
                self.assertEqual(list(destination.parent.glob('.migration-*')), [])

    def test_interruption_after_menu_publish_retries_without_duplicate_actions(self):
        legacy = self.legacy_menu()
        result = self.fault_migration('''
original = module.atomic_json
def interrupt_after_write(path, *args, **kwargs):
    original(path, *args, **kwargs)
    if path.name == 'hakumenu-general.json':
        os.kill(os.getpid(), signal.SIGTERM)
module.atomic_json = interrupt_after_write
''')
        self.assertEqual(result.returncode, -15)
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        original = destination.read_bytes()
        self.run_script('migrate.sh', '--complete', ok=False)
        self.run_script('migrate.sh', '--apply')
        self.run_script('migrate.sh', '--complete')
        self.assertEqual(destination.read_bytes(), original)
        ids = [row['id'] for row in json.loads(original)['items']]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual((self.home / 'backup/hakucfg/general-menu.sh').read_bytes(), legacy.read_bytes())

    def test_interrupted_default_replacement_reuses_the_original_backup(self):
        self.legacy_menu()
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        destination.parent.mkdir()
        default = (self.repo / 'src/home/hakucfg/config/hakumenu-general.json').read_bytes()
        destination.write_bytes(default)
        result = self.fault_migration('''
original = module.atomic_json
def interrupt_after_write(path, *args, **kwargs):
    original(path, *args, **kwargs)
    if path.name == 'hakumenu-general.json':
        os.kill(os.getpid(), signal.SIGTERM)
module.atomic_json = interrupt_after_write
''')
        self.assertEqual(result.returncode, -15)
        destination.write_text(json.dumps(json.loads(destination.read_text()), indent=4))
        converted = destination.read_bytes()
        self.run_script('migrate.sh', '--apply')
        self.run_script('migrate.sh', '--complete')
        self.assertEqual(destination.read_bytes(), converted)
        self.assertEqual((self.home / 'backup/hakucfg/config/hakumenu-general.json').read_bytes(), default)

    def test_corrupted_publication_is_checked_before_recording_success(self):
        self.legacy_menu()
        result = self.fault_migration('''
original = module.atomic_json
def corrupt_after_write(path, *args, **kwargs):
    original(path, *args, **kwargs)
    if path.name == 'hakumenu-general.json':
        (module.HOME / 'generated-menu.json').write_bytes(path.read_bytes())
        path.write_text('{broken')
module.atomic_json = corrupt_after_write
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('malformed', result.stderr)
        self.assertEqual(json.loads(self.receipt.read_text())['status'], 'failed')
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        self.run_script('migrate.sh', '--complete', ok=False)
        destination.write_bytes((self.home / 'generated-menu.json').read_bytes())
        self.run_script('migrate.sh', '--apply')
        self.run_script('migrate.sh', '--complete')

    # Ensure compiled caches cannot enter deployment or doctor expectations.
    def test_core_catalog_and_copy_preserve_user_files(self):
        source = self.repo / 'src/core/backend/user/general_menu_ctl.py'
        py_compile.compile(str(source), doraise=True)
        (source.parent / 'ignored.pyo').write_bytes(b'bytecode')
        custom = self.bin / 'user-script'
        custom.write_text('personal')
        for mode in ('copy', 'copy', 'symlink'):
            self.run_script('core.sh', '--mode', mode)
            self.assertEqual(custom.read_text(), 'personal')
            self.assertFalse(any(path.suffix in ('.pyc', '.pyo') for path in self.bin.iterdir()))
            if mode == 'copy':
                executable = self.bin / 'general_menu_ctl.py'
                self.assertTrue(os.access(executable, os.X_OK))
                executable.chmod(0o644)
        self.assertFalse((self.home / 'backup/.local/bin/user-script').exists())

    # Keep rollback and unlink on the same filtered catalog used by deployment.
    def test_registry_consumers_and_redirected_bin(self):
        source = self.repo / 'src/core/backend/user/general_menu_ctl.py'
        py_compile.compile(str(source), doraise=True)
        result = subprocess.run(['bash', '-c', f"source '{self.repo}/scripts/variables.sh'; registry_get_managed_destinations"],
                                env=self.env, text=True, capture_output=True, check=True)
        self.assertNotIn('.pyc', result.stdout)
        self.run_script('core.sh')
        custom = self.bin / 'user-script'
        custom.write_text('keep')
        self.run_script('unlink.sh', 'core')
        self.assertEqual(list(self.bin.iterdir()), [custom])
        custom.unlink()
        self.bin.rmdir()
        external = self.home / 'external-bin'
        external.mkdir()
        self.bin.symlink_to(external)
        self.run_script('core.sh', '--mode', 'copy', ok=False)
        self.assertTrue(self.bin.is_symlink())
        self.assertEqual(list(external.iterdir()), [])

    # Check ignored executable-looking artifacts against a real Git source catalog.
    def test_git_catalog_excludes_ignored_python(self):
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        (self.repo / '.gitignore').write_text('src/core/runtime.py\n')
        subprocess.run(['git', '-C', str(self.repo), 'add', '.'], check=True)
        ignored = self.repo / 'src/core/runtime.py'
        ignored.write_text('print("ignored runtime")\n')
        self.run_script('core.sh')
        self.assertFalse((self.bin / 'runtime.py').exists())
        self.assertTrue((self.bin / 'general_menu_ctl.py').is_symlink())

    # Preserve modified copies while backing up only checksum-proven legacy CSS.
    def test_copy_manifest_ownership_and_facade_redeployment(self):
        manifest = json.loads((self.repo / 'scripts/migrations/v26.10-1.json').read_text())
        css = self.home / '.config/gtk-3.0/gtk.css'
        css.parent.mkdir(parents=True)
        css.write_bytes(subprocess.check_output(['git', '-C', str(ROOT), 'show',
                       'v26.10-1:src/home/.config/gtk-3.0/gtk.css']))
        legacy = self.bin / 'record.sh'
        entry = next(row for row in manifest['files'] if row['destination'].endswith('/record.sh'))
        legacy.symlink_to(self.repo / entry['source'])
        self.run_script('migrate.sh', '--apply', ok=False)
        self.assertFalse(css.exists())
        self.assertTrue((self.home / 'backup/.config/gtk-3.0/gtk.css').is_file())
        self.assertTrue(legacy.is_symlink())
        self.run_script('core.sh')
        self.run_script('migrate.sh', '--apply')
        css.write_text('custom CSS')
        self.run_script('migrate.sh', '--apply')
        self.assertEqual(css.read_text(), 'custom CSS')

    # Require a full collision scan before the first destination is changed.
    def test_core_collision_is_rejected_before_deploy(self):
        duplicate = self.repo / 'src/core/duplicate'
        duplicate.mkdir()
        (duplicate / 'general_menu_ctl.py').write_text('pass\n')
        self.run_script('core.sh', ok=False)
        self.assertEqual(list(self.bin.iterdir()), [])

    # Verify exact target ownership and retain unproven legacy data on repeated runs.
    def test_plan_is_read_only_and_cleanup_is_idempotent(self):
        owned = self.bin / 'old.cpython-314.pyc'
        owned.symlink_to(self.repo / 'src/core/lib/__pycache__/old.cpython-314.pyc')
        alias = self.bin / 'user-alias.pyc'
        alias.symlink_to(self.repo / 'src/core/lib/__pycache__/old.cpython-314.pyc')
        custom = self.bin / 'custom.pyc'
        custom.symlink_to(self.home / 'other/__pycache__/custom.pyc')
        regular = self.bin / 'user.pyc'
        regular.write_bytes(b'keep')
        gtk = self.home / '.config/gtk-3.0/gtk.css'
        gtk.parent.mkdir(parents=True)
        gtk.symlink_to(self.repo / 'src/home/.config/gtk-3.0/gtk.css')
        before = sorted(str(path.relative_to(self.home)) for path in self.home.rglob('*'))
        self.run_script('migrate.sh', '--plan')
        self.assertEqual(before, sorted(str(path.relative_to(self.home)) for path in self.home.rglob('*')))
        self.run_script('migrate.sh', '--apply')
        self.assertFalse(owned.is_symlink())
        self.assertFalse(gtk.is_symlink())
        self.assertTrue(custom.is_symlink())
        self.assertTrue(alias.is_symlink())
        self.assertEqual(regular.read_bytes(), b'keep')
        self.assertEqual(json.loads(self.receipt.read_text())['status'], 'pending')
        self.run_script('migrate.sh', '--complete')
        self.run_script('migrate.sh', '--apply')
        self.assertTrue(custom.is_symlink())
        self.assertTrue((self.home / 'backup/.local/bin/old.cpython-314.pyc').is_symlink())

    # Retain source bytes and stable IDs while accepting only the original grammar.
    def test_general_menu_conversion_and_manual_failure(self):
        legacy = self.home / 'hakucfg/general-menu.sh'
        legacy.parent.mkdir()
        raw = subprocess.check_output(['git', '-C', str(ROOT), 'show', 'v26.10-1:src/home/hakucfg/general-menu.sh'])
        legacy.write_bytes(raw.replace(b'spawn code', b'spawn code --new-window'))
        self.run_script('migrate.sh', '--apply')
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        document = json.loads(destination.read_text())
        self.assertEqual(document['items'][1]['argv'], ['code', '--new-window'])
        self.assertEqual(legacy.read_bytes(), raw.replace(b'spawn code', b'spawn code --new-window'))
        original = destination.read_bytes()
        self.run_script('migrate.sh', '--apply')
        self.assertEqual(destination.read_bytes(), original)
        legacy.write_text(legacy.read_text() + '\ntouch "$HOME/executed"\n')
        self.receipt.unlink()
        result = self.run_script('migrate.sh', '--apply', ok=False)
        self.assertIn('manual migration required', result.stdout)
        self.assertEqual(destination.read_bytes(), original)
        self.assertFalse((self.home / 'executed').exists())
        self.run_script('migrate.sh', '--complete', ok=False)
        self.assertNotEqual(json.loads(self.receipt.read_text())['status'], 'applied')

    # Completed conversion must leave subsequent valid user edits under user control.
    def test_applied_menu_preserves_later_json_edits(self):
        legacy = self.home / 'hakucfg/general-menu.sh'
        legacy.parent.mkdir()
        legacy.write_bytes(subprocess.check_output(['git', '-C', str(ROOT), 'show',
                           'v26.10-1:src/home/hakucfg/general-menu.sh']))
        self.run_script('migrate.sh', '--apply')
        self.run_script('migrate.sh', '--complete')
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        document = json.loads(destination.read_text())
        document['items'][0]['label'] = 'My launcher'
        destination.write_text(json.dumps(document))
        edited = destination.read_bytes()
        self.run_script('migrate.sh', '--apply')
        self.run_script('migrate.sh', '--complete')
        self.assertEqual(destination.read_bytes(), edited)
        self.assertEqual(json.loads(self.receipt.read_text())['steps']['v26.11-menu']['status'], 'applied')

    # Refuse redirected state and menu paths before modifying outside destinations.
    def test_symlinked_storage_is_preserved(self):
        external = self.home / 'external'
        external.mkdir()
        state = self.home / '.local/state'
        state.parent.mkdir(exist_ok=True)
        state.symlink_to(external)
        self.run_script('migrate.sh', '--apply', ok=False)
        self.assertEqual(list(external.iterdir()), [])

    # Core and services remain attempted when a compositor package fails.
    def test_package_groups_continue_and_report_exact_exit(self):
        self.command('yay', '''packages=$(cat)
printf '%s\\n--GROUP--\\n' "$packages" >> "$HOME/packages.log"
if [[ "$packages" == *niri* ]]; then echo 'mock niri failure'; exit 37; fi
''')
        result = self.run_script('packages.sh', '--profile', 'update', 'niri', ok=False)
        groups = (self.home / 'packages.log').read_text().split('--GROUP--')
        self.assertIn('quickshell', groups[0])
        self.assertIn('qt6-multimedia-ffmpeg', groups[0])
        self.assertIn('niri', groups[2])
        self.assertIn('exit=37', result.stdout)
        self.assertIn('mock niri failure', (self.home / 'backup/packages/NIRI.log').read_text())
        self.run_script('packages.sh', '--repair-missing', 'core')
        self.assertEqual((self.home / 'packages.log').read_text().count('--GROUP--'), 3)

    # Non-Arch system configuration must never invoke Arch package transactions.
    def test_nixos_never_uses_pacman_or_yay(self):
        self.command('nixos-rebuild', 'exit 0\n')
        self.command('pacman', 'touch "$HOME/pacman-called"\nexit 1\n')
        self.command('yay', 'touch "$HOME/yay-called"\nexit 1\n')
        self.run_script('packages.sh', '--repair-missing', 'core', ok=False)
        self.run_script('packages.sh', '--audit-runtime')
        self.assertFalse((self.home / 'pacman-called').exists())
        self.assertFalse((self.home / 'yay-called').exists())

    # Preserve Git failures and stop before pull when checkout itself fails.
    def test_repo_update_propagates_git_errors(self):
        self.command('git', 'echo "$*" >> "$HOME/git-called"\nif [[ "$*" == *rev-parse* ]]; then echo before; exit 0; fi\nexit 23\n')
        result = self.run_script('repo_update.sh', '--mode', 'latest', ok=False)
        self.assertEqual(result.returncode, 23)
        self.assertIn('checkout main', (self.home / 'git-called').read_text())
        self.assertNotIn('pull', (self.home / 'git-called').read_text())

    # A module-only Git update must request a reload even when update.sh is identical.
    def test_repo_revision_change_reexecs_for_module_only_update(self):
        shutil.copy2(ROOT / 'update.sh', self.repo / 'update.sh')
        git_env = dict(self.env, GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.invalid',
                       GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.invalid')
        def git(*args):
            return subprocess.run(['git', *map(str, args)], env=git_env, text=True,
                                  capture_output=True, check=True)
        git('init', '-b', 'main', self.repo)
        git('-C', self.repo, 'add', '.')
        git('-C', self.repo, 'commit', '-m', 'baseline fixture')
        upstream = self.home / 'upstream'
        git('clone', self.repo, upstream)
        git('-C', self.repo, 'remote', 'add', 'origin', upstream)
        registry = upstream / 'scripts/registry.sh'
        registry.write_text(registry.read_text() + '\n# Updated module fixture.\n')
        git('-C', upstream, 'add', 'scripts/registry.sh')
        git('-C', upstream, 'commit', '-m', 'module-only fixture')
        unchanged = (self.repo / 'update.sh').read_bytes()
        changed = self.run_script('repo_update.sh', '--mode', 'latest', ok=False)
        self.assertEqual(changed.returncode, 10, changed.stdout + changed.stderr)
        self.assertEqual((self.repo / 'update.sh').read_bytes(), unchanged)
        self.run_script('repo_update.sh', '--mode', 'latest')

    # Use real deployment and migration while replacing desktop and network side effects.
    def test_updater_final_failure_and_retry_with_real_receipt(self):
        shutil.copy2(ROOT / 'update.sh', self.repo / 'update.sh')
        legacy = self.home / 'hakucfg/general-menu.sh'
        legacy.parent.mkdir()
        legacy.write_bytes(subprocess.check_output(['git', '-C', str(ROOT), 'show',
                           'v26.10-1:src/home/hakucfg/general-menu.sh']))
        helpers = self.repo / 'scripts/functions.sh'
        helpers.write_text(helpers.read_text() + '\nask_yes_no() { [[ "$1" == *configuration* ]]; }\n')
        for name, body in {
            'repo_update': 'exit 0', 'select_wm': 'echo niri', 'deploy_mode': 'echo symlink',
            'link': 'exec "$HAKU_DIR/scripts/core.sh" --mode symlink',
            'setup': '[[ "$1" != path ]]', 'state': 'exit 0', 'hakucfg': 'exit 0',
            'reload': 'exit 0', 'doctor': 'exit 7',
        }.items():
            (self.repo / f'scripts/{name}.sh').write_text('#!/bin/bash\n' + body + '\n')
        first = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env, text=True, capture_output=True)
        self.assertNotEqual(first.returncode, 0, first.stdout + first.stderr)
        self.assertNotIn('Update complete!', first.stdout)
        self.assertEqual(json.loads(self.receipt.read_text())['status'], 'pending')
        (self.repo / 'scripts/doctor.sh').write_text('#!/bin/bash\nexit 0\n')
        retry = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env, text=True, capture_output=True)
        self.assertEqual(retry.returncode, 0, retry.stdout + retry.stderr)
        self.assertEqual(json.loads(self.receipt.read_text())['status'], 'applied')
        self.assertIn('Update complete!', retry.stdout)
        destination = self.home / 'hakucfg/config/hakumenu-general.json'
        document = json.loads(destination.read_text())
        document['items'][0]['label'] = 'Edited after migration'
        destination.write_text(json.dumps(document))
        edited = destination.read_bytes()
        again = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env, text=True, capture_output=True)
        self.assertEqual(again.returncode, 0, again.stdout + again.stderr)
        self.assertEqual(destination.read_bytes(), edited)
        self.assertEqual(json.loads(self.receipt.read_text())['status'], 'applied')


    # A runtime audit must fail even when package installation was skipped.
    def test_runtime_audit_detects_missing_module(self):
        self.command('quickshell', 'echo "module QtMultimedia is not installed" >&2\nexit 4\n')
        self.run_script('packages.sh', '--audit-runtime', ok=False)

    # Doctor shares the executable catalog and returns failure for an actual missing target.
    def test_doctor_ignores_bytecode_but_rejects_missing_core(self):
        self.run_script('core.sh')
        for name in ('state', 'hakucfg'):
            (self.repo / f'scripts/{name}.sh').write_text('#!/bin/bash\nexit 0\n')
        code = f'''source '{self.repo}/scripts/doctor.sh'
registry_get_common_configs() {{ :; }}
run_doctor
'''
        env = dict(self.env, HAKUSPACE_DEPLOY_MODE='symlink')
        result = subprocess.run(['bash', '-c', code], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        state = self.home / '.local/state/hakuspace/state/[shell].backend'
        state.parent.mkdir(parents=True)
        self.command('quickshell', 'echo "missing QtMultimedia" >&2\nexit 4\n')
        for backend in ('classic', 'hikai'):
            with self.subTest(backend=backend):
                state.write_text(backend)
                missing = subprocess.run(['bash', '-c', code], env=env, text=True, capture_output=True)
                self.assertNotEqual(missing.returncode, 0, missing.stdout + missing.stderr)
                self.assertIn('shared Quickshell/QtMultimedia', missing.stdout)
        self.command('quickshell', 'exit 0\n')
        (self.bin / 'general_menu_ctl.py').unlink()
        result = subprocess.run(['bash', '-c', code], env=env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('general_menu_ctl.py', result.stdout)


if __name__ == '__main__':
    unittest.main()
