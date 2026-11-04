#!/usr/bin/env python3
"""Exercise upgrade boundaries with private homes and package-manager doubles."""
import json
import os
from pathlib import Path
import py_compile
import shutil
import subprocess
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
