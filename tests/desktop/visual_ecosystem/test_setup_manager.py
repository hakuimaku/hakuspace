"""Federated Git, installer and wallpaper contracts using private local remotes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
COMPONENTS = {'cursor': 'haku-cursor', 'gtk': 'hikade-gtk-theme', 'symbols': 'hikaide-symbols'}

# A single cheap upstream fixture exposes each project's supported build/install API.
INSTALLER = r'''import os
from pathlib import Path
import shutil
import sys
component, action = sys.argv[1:3]
if action == 'build':
    with open(os.environ['TEST_BUILDS'], 'a') as log:
        log.write(component + '\n')
    if os.environ.get('TEST_FAIL_COMPONENT') == component:
        sys.exit(7)
if action == 'cursor-build':
    with open(os.environ['TEST_BUILDS'], 'a') as log:
        log.write('cursor\n')
    if os.environ.get('TEST_FAIL_COMPONENT') == 'cursor': sys.exit(7)
    theme = os.environ.get('HAKU_CURSOR_THEME', 'Haku-Dark')
    target = Path('dist') / theme
    (target / 'cursors').mkdir(parents=True, exist_ok=True)
    (target / 'index.theme').write_text('[Icon Theme]\nName=' + theme + '\n')
    (target / 'cursors/left_ptr').write_text('cursor')
if action == 'install':
    if component == 'cursor':
        theme = os.environ.get('HAKU_CURSOR_THEME', 'Haku-Dark')
        target = Path.home() / '.icons' / theme
        if target.exists(): shutil.rmtree(target)
        shutil.copytree(Path('dist') / theme, target)
    else:
        names = ('Hikaide', 'Hikaide-Light') if component == 'gtk' else ('Hikaide-Symbols', 'Hikaide-Symbols-Light')
        root = Path.home() / ('.themes' if component == 'gtk' else '.icons')
        for name in names:
            target = root / name
            target.mkdir(parents=True, exist_ok=True)
            (target / 'index.theme').write_text('[Icon Theme]\nName=' + name + '\n')
'''


class WorkspaceFixture(unittest.TestCase):
    def setUp(self):
        """Create isolated orchestration, upstreams and Git URL rewrites without network."""
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.home = Path(self.work.name)
        self.repo = self.home / 'hakuspace'
        shutil.copytree(ROOT / 'scripts', self.repo / 'scripts')
        shutil.copy2(ROOT / '.gitignore', self.repo / '.gitignore')
        core = self.repo / 'src/core'
        (core / 'lib').mkdir(parents=True)
        for name in ('haku_appearance.sh', 'haku_state.sh'):
            shutil.copy2(ROOT / 'src/core/lib' / name, core / 'lib' / name)
        (core / 'backend/theme').mkdir(parents=True)
        for name in ('appearance_ctl.sh', 'theme_ctl.sh'):
            path = core / 'backend/theme' / name
            path.write_text('#!/bin/sh\nprintf "%s %s\\n" "$(basename "$0")" "$*" >> "$TEST_RECONCILE"\n'
                            'if [ "${TEST_RECONCILE_FAIL:-0}" = 1 ]; then exit 8; fi\n')
            path.chmod(0o755)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(('HAKU_', 'HAKUSPACE_', 'GIT_'))}
        self.env.update(HOME=str(self.home), HAKU_DIR=str(self.repo),
                        XDG_CONFIG_HOME=str(self.home / 'config'),
                        XDG_STATE_HOME=str(self.home / 'state'), XDG_DATA_HOME=str(self.home / 'data'),
                        GIT_CONFIG_GLOBAL=str(self.home / 'gitconfig'), GIT_CONFIG_NOSYSTEM='1',
                        GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.invalid',
                        GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.invalid',
                        GIT_TERMINAL_PROMPT='0', PYTHONDONTWRITEBYTECODE='1',
                        TEST_BUILDS=str(self.home / 'builds'), TEST_RECONCILE=str(self.home / 'reconcile'),
                        TEST_GIT_LOG=str(self.home / 'git-calls'), TEST_REAL_GIT=shutil.which('git'))
        self.remotes = {}
        for component, name in COMPONENTS.items():
            remote = self.home / 'remotes' / name
            remote.mkdir(parents=True)
            self.git('init', '-b', 'main', remote)
            (remote / 'revision').write_text('initial')
            (remote / '.gitignore').write_text('dist/\n__pycache__/\n')
            (remote / 'fixture.py').write_text(INSTALLER)
            scripts = remote / 'scripts'
            scripts.mkdir()
            if component == 'cursor':
                (remote / 'Makefile').write_text('STYLE ?= dark\n.PHONY: dark light blue verify install\n'
                                               'dark light blue:\n\tpython3 fixture.py cursor cursor-build\n'
                                               'verify:\n\t@true\ninstall:\n\tpython3 fixture.py cursor install\n')
            elif component == 'gtk':
                (scripts / 'install_gtk_theme.py').write_text(
                    "import runpy, sys\nfrom pathlib import Path\n"
                    "sys.argv = ['fixture.py', 'gtk', 'build']\n"
                    "runpy.run_path(str(Path(__file__).parents[1] / 'fixture.py'))\n"
                    "sys.argv = ['fixture.py', 'gtk', 'install']\n"
                    "runpy.run_path(str(Path(__file__).parents[1] / 'fixture.py'))\n")
            else:
                (scripts / 'build.py').write_text("import runpy, sys\nsys.argv = ['fixture.py', 'symbols', 'build']\nrunpy.run_path('fixture.py')\n")
                (scripts / 'validate.py').write_text('# Fixture output validation succeeds.\n')
                install = scripts / 'install.sh'
                install.write_text('#!/bin/sh\nexec python3 fixture.py symbols install\n')
                install.chmod(0o755)
            self.git('-C', remote, 'add', '.')
            self.git('-C', remote, 'commit', '-m', 'initial')
            self.git('config', '--global', f'url.{remote.as_uri()}.insteadOf', f'https://github.com/hakuimaku/{name}.git')
            self.remotes[component] = remote
        self.binary = self.home / 'bin'
        self.binary.mkdir()
        wrapper = self.binary / 'git'
        wrapper.write_text(r'''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['TEST_GIT_LOG'], 'a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\n')
os.execv(os.environ['TEST_REAL_GIT'], ['git', *sys.argv[1:]])
''')
        wrapper.chmod(0o755)
        self.env['PATH'] = str(self.binary) + ':' + self.env['PATH']

    def git(self, *args):
        """Operate on disposable test history without polluting the manager call log."""
        return subprocess.run([self.env['TEST_REAL_GIT'], *map(str, args)], env=self.env,
                              check=True, text=True, capture_output=True).stdout.strip()

    def run_manager(self, *args, success=True):
        """Run the real CLI from outside its checkout."""
        result = subprocess.run(['bash', str(self.repo / 'scripts/setup.sh'), *args],
                                env=self.env, cwd=self.home, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def child(self, component):
        """Resolve fallback clone paths outside the HakuSpace checkout."""
        return self.home / COMPONENTS[component]

    def lines(self, name):
        """Read an optional fixture log."""
        path = self.home / name
        return path.read_text().splitlines() if path.exists() else []

    def clear_logs(self):
        """Separate update effects from the preceding bootstrap."""
        for name in ('builds', 'reconcile', 'git-calls'):
            (self.home / name).unlink(missing_ok=True)

    def assert_no_manifest(self):
        """Persistent visual state contains intent/recovery only, never Git metadata."""
        self.assertFalse((self.home / '.local/state/hakuspace/assets/installed.env').exists())
        state = self.home / '.local/state/hakuspace/state'
        self.assertFalse(any('REV' in path.read_text() or 'DIRTY' in path.read_text()
                             for path in state.glob('*') if path.is_file()))

    def source_config(self):
        """Resolve the centralized source intent fixture."""
        return self.home / '.local/state/hakuspace/state/[system].visual-sources.json'

    def pending(self):
        """Resolve the operational activation-retry flag."""
        return self.home / '.local/state/hakuspace/state/[system].visual-reconcile.pending'

    def advance(self, component, text='upstream'):
        """Publish a new local upstream revision for a single component."""
        remote = self.remotes[component]
        (remote / 'revision').write_text(text)
        self.git('-C', remote, 'commit', '-am', text)
        return self.git('-C', remote, 'rev-parse', 'HEAD')



class WorkspaceTests(WorkspaceFixture):
    def test_path_and_status_are_read_only(self):
        """Inspection never bootstraps sources or creates state."""
        result = self.run_manager('path', 'symbols')
        self.assertEqual(result.stdout.strip(), str(self.child('symbols')))
        self.assertIn('symbols\tmissing\t', self.run_manager('status').stdout)
        self.assertFalse((self.repo / 'ecosystem').exists())
        self.assertFalse((self.home / '.local/state').exists())
        self.run_manager('apply', 'unknown', success=False)

    def test_bootstrap_full_clones_and_reuse(self):
        """Fallback sources are independent full clones outside HakuSpace."""
        self.run_manager('setup')
        self.assertEqual(self.lines('builds'), ['cursor', 'gtk', 'symbols'])
        self.assertEqual(len(self.lines('reconcile')), 3)
        for component in COMPONENTS:
            self.assertTrue((self.child(component) / '.git').is_dir())
            self.assertEqual(self.git('-C', self.child(component), 'rev-parse', '--is-shallow-repository'), 'false')
            self.assertNotIn(self.repo, self.child(component).parents)
        self.run_manager('setup')
        clones = [json.loads(line) for line in self.lines('git-calls') if json.loads(line)[0] == 'clone']
        self.assertEqual(len(clones), 3)
        self.assertTrue(all('--depth' not in args for args in clones))
        self.assertEqual(self.lines('builds'), ['cursor', 'gtk', 'symbols'] * 2)
        self.assert_no_manifest()
        self.assertFalse(self.source_config().exists())

    def test_update_only_changed_components_and_reconcile_once(self):
        """Fast-forwarding one source installs only that component; unchanged skips builds."""
        self.run_manager('setup')
        revision = self.advance('symbols')
        self.clear_logs()
        self.run_manager('update')
        self.assertEqual(self.lines('builds'), ['symbols'])
        self.assertEqual(len(self.lines('reconcile')), 3)
        self.assertEqual(self.git('-C', self.child('symbols'), 'rev-parse', 'HEAD'), revision)
        self.assert_no_manifest()
        self.clear_logs()
        self.run_manager('update')
        self.assertEqual(self.lines('builds'), [])
        self.assertEqual(self.lines('reconcile'), ['appearance_ctl.sh verify'])

    def test_dirty_update_preserves_sources_and_explicit_apply_records_dirty(self):
        """Automatic update skips dirty files; explicit apply builds them without pulling."""
        self.run_manager('setup')
        path = self.child('symbols')
        (path / 'revision').write_text('local edits')
        (path / 'personal').write_text('keep')
        self.clear_logs()
        result = self.run_manager('update')
        self.assertIn('dirty, skipped', result.stdout)
        self.assertEqual(self.lines('builds'), [])
        self.assertEqual((path / 'personal').read_text(), 'keep')
        calls = [json.loads(line) for line in self.lines('git-calls')]
        self.assertFalse(any(str(path) in args and 'pull' in args for args in calls))
        self.clear_logs()
        self.run_manager('apply', 'symbols')
        self.assertEqual(self.lines('builds'), ['symbols'])
        self.assert_no_manifest()
        self.assertEqual((path / 'revision').read_text(), 'local edits')
        self.assertEqual((path / 'personal').read_text(), 'keep')
        calls = [json.loads(line) for line in self.lines('git-calls')]
        self.assertFalse(any(any(command in args for command in ('pull', 'reset', 'stash', 'checkout', 'restore', 'clean', 'rebase', 'merge')) for args in calls))

    def test_dirty_setup_warns_and_installs_without_pulling(self):
        """A deliberate full setup may install local dirty development contents."""
        self.run_manager('setup')
        path = self.child('gtk')
        (path / 'revision').write_text('local changes')
        self.clear_logs()
        result = self.run_manager('setup')
        self.assertIn('warning: full setup installs current dirty gtk tree', result.stderr)
        self.assert_no_manifest()
        calls = [json.loads(line) for line in self.lines('git-calls')]
        self.assertFalse(any(str(path) in args and 'pull' in args for args in calls))

    def test_override_lifecycle_is_unmanaged_and_apply_is_explicit(self):
        """Overrides are never cloned or pulled and stay outside the workspace."""
        source = self.remotes['symbols']
        (source / 'revision').write_text('local override')
        self.env['HAKU_ICON_THEME_SOURCE'] = str(source)
        self.run_manager('update')
        self.assertFalse(self.child('symbols').exists())
        self.assertEqual(self.lines('builds'), ['cursor', 'gtk'])
        self.assertEqual(self.run_manager('path', 'symbols').stdout.strip(), str(source))
        self.clear_logs()
        self.run_manager('apply', 'symbols')
        self.assertEqual(self.lines('builds'), ['symbols'])
        self.assert_no_manifest()
        self.assertEqual((source / 'revision').read_text(), 'local override')
        self.assertFalse(any('pull' in json.loads(line) for line in self.lines('git-calls')))

    def test_non_git_override_records_unknown_revision_and_missing_override_fails(self):
        """Local directories are usable without falsely claiming a clean Git revision."""
        source = self.home / 'local symbols'
        shutil.copytree(self.remotes['symbols'], source, ignore=shutil.ignore_patterns('.git'))
        self.env['HAKU_ICON_THEME_SOURCE'] = str(source)
        self.run_manager('apply', 'symbols')
        self.assertIn('unknown\tdirty=unknown', self.run_manager('status').stdout)
        self.assert_no_manifest()
        self.assertFalse((source / '.git').exists())
        self.assertFalse(self.child('symbols').exists())
        self.env['HAKU_ICON_THEME_SOURCE'] = str(self.home / 'missing')
        self.run_manager('apply', 'symbols', success=False)
        self.assertFalse((self.home / 'missing').exists())

    def test_detached_no_upstream_and_wrong_origin_are_not_repaired(self):
        """Developer branch state wins over automatic update."""
        self.run_manager('setup')
        path = self.child('symbols')
        revision = self.git('-C', path, 'rev-parse', 'HEAD')
        self.git('-C', path, 'checkout', '--detach')
        self.clear_logs()
        self.assertIn('unmanaged, skipped', self.run_manager('update').stdout)
        self.assertEqual(self.git('-C', path, 'rev-parse', 'HEAD'), revision)
        self.git('-C', path, 'checkout', 'main')
        self.git('-C', path, 'branch', '--unset-upstream')
        self.assertIn('unmanaged, skipped', self.run_manager('update').stdout)
        self.git('-C', path, 'remote', 'set-url', 'origin', 'https://example.invalid/unrelated.git')
        result = self.run_manager('update', success=False)
        self.assertIn('Wrong origin', result.stderr)
        self.assertEqual(self.lines('builds'), [])
        self.assertEqual(self.git('-C', path, 'config', '--get', 'remote.origin.url'), 'https://example.invalid/unrelated.git')

    def test_divergent_pull_fails_without_changing_local_history(self):
        """A failed fast-forward preserves local commits and installed revision metadata."""
        self.run_manager('setup')
        path = self.child('cursor')
        (path / 'revision').write_text('local commit')
        self.git('-C', path, 'commit', '-am', 'local')
        local = self.git('-C', path, 'rev-parse', 'HEAD')
        self.advance('cursor', 'remote commit')
        self.advance('gtk')
        self.clear_logs()
        self.run_manager('update', success=False)
        self.assertEqual(self.git('-C', path, 'rev-parse', 'HEAD'), local)
        self.assertEqual((path / 'revision').read_text(), 'local commit')
        self.assert_no_manifest()
        self.assertEqual(self.lines('builds'), ['gtk'])

    def test_build_failures_preserve_checkout_and_explicit_apply_retries(self):
        """Failed installs return failure without inventing persistent installed revisions."""
        self.run_manager('setup')
        for component in COMPONENTS:
            with self.subTest(component=component):
                revision = self.advance(component)
                self.env['TEST_FAIL_COMPONENT'] = component
                self.clear_logs()
                self.run_manager('update', success=False)
                self.assertTrue((self.child(component) / '.git').is_dir())
                self.assertEqual(self.git('-C', self.child(component), 'rev-parse', 'HEAD'), revision)
                self.assert_no_manifest()
                self.env.pop('TEST_FAIL_COMPONENT')
                self.clear_logs()
                self.run_manager('update')
                self.assertEqual(self.lines('builds'), [])
                self.run_manager('apply', component)
                self.assertEqual(self.lines('builds'), [component])

    def test_non_repository_and_symlink_paths_are_preserved(self):
        """Invalid child targets fail without deleting user files or following symlinks."""
        path = self.child('cursor')
        path.mkdir(parents=True)
        (path / 'personal').write_text('keep')
        self.run_manager('update', success=False)
        self.assertEqual((path / 'personal').read_text(), 'keep')
        saved = self.home / 'saved'
        path.rename(saved)
        path.symlink_to(saved)
        self.run_manager('update', success=False)
        self.assertTrue(path.is_symlink())
        self.assertEqual((saved / 'personal').read_text(), 'keep')

    def test_arbitrary_source_paths_persist_as_intent_and_environment_wins(self):
        """Configured roots need no shared parent and are never relocated or recloned."""
        paths = {'cursor': self.home / 'a/cursor', 'gtk': self.home / 'b/themes/gtk',
                 'symbols': self.home / 'c symbols'}
        variables = {'cursor': 'HAKU_CURSOR_SOURCE', 'gtk': 'HAKU_GTK_THEME_SOURCE', 'symbols': 'HAKU_ICON_THEME_SOURCE'}
        for component, path in paths.items():
            shutil.copytree(self.remotes[component], path)
            self.env[variables[component]] = str(path.relative_to(self.home))
        self.run_manager('setup')
        self.assertEqual(json.loads(self.source_config().read_text()), {key: str(path) for key, path in paths.items()})
        self.assertFalse(any(self.child(component).exists() for component in COMPONENTS))
        for component, path in paths.items():
            self.env.pop(variables[component])
            self.assertEqual(self.run_manager('path', component).stdout.strip(), str(path))
        self.env['HAKU_ICON_THEME_SOURCE'] = str(self.remotes['symbols'])
        self.assertEqual(self.run_manager('path', 'symbols').stdout.strip(), str(self.remotes['symbols']))
        self.assert_no_manifest()
        self.assertFalse(any('clone' in json.loads(line) or 'pull' in json.loads(line) for line in self.lines('git-calls')))

    def test_source_state_is_data_and_read_only_commands_ignore_legacy_shell(self):
        """Neither legacy shell configuration nor malformed central state executes code."""
        legacy = self.home / 'config/hakuspace/appearance.env'
        legacy.parent.mkdir(parents=True)
        legacy.write_text('touch "$HOME/executed"\nHAKU_CURSOR_SOURCE=/unexpected\n')
        self.run_manager('status')
        self.run_manager('path', 'cursor')
        self.assertFalse((self.home / 'executed').exists())
        self.assertFalse(self.source_config().exists())
        self.source_config().parent.mkdir(parents=True)
        self.source_config().write_text('{"cursor": "$(touch $HOME/executed)"}')
        self.run_manager('status', success=False)
        self.assertFalse((self.home / 'executed').exists())
        self.source_config().unlink()
        self.source_config().symlink_to(legacy)
        self.run_manager('status', success=False)
        self.assertTrue(self.source_config().is_symlink())

    def test_source_intent_replacement_failure_preserves_previous_state(self):
        """Failed atomic source-state replacement leaves prior intent and no temp files."""
        self.env['HAKU_ICON_THEME_SOURCE'] = str(self.remotes['symbols'])
        self.run_manager('apply', 'symbols')
        before = self.source_config().read_bytes()
        alternate = self.home / 'alternate symbols'
        shutil.copytree(self.remotes['symbols'], alternate)
        self.env['HAKU_ICON_THEME_SOURCE'] = str(alternate)
        wrapper = self.binary / 'mv'
        wrapper.write_text('#!/bin/sh\nexit 9\n')
        wrapper.chmod(0o755)
        self.run_manager('apply', 'symbols', success=False)
        self.assertEqual(self.source_config().read_bytes(), before)
        self.assertEqual(list(self.source_config().parent.glob('*.json.*')), [])
        wrapper.unlink()
        self.run_manager('apply', 'symbols')
        self.assertEqual(json.loads(self.source_config().read_text())['symbols'], str(alternate))
        self.assert_no_manifest()

    def test_reconcile_failure_retries_on_unchanged_update_and_verify(self):
        """Runtime activation failures never force unchanged source trees to rebuild."""
        self.env['TEST_RECONCILE_FAIL'] = '1'
        self.run_manager('setup', success=False)
        self.assertTrue(self.pending().exists())
        self.env.pop('TEST_RECONCILE_FAIL')
        self.clear_logs()
        self.run_manager('update')
        self.assertEqual(self.lines('builds'), [])
        self.assertEqual(len(self.lines('reconcile')), 3)
        self.assertFalse(self.pending().exists())
        self.env['TEST_RECONCILE_FAIL'] = '1'
        self.run_manager('apply', 'gtk', success=False)
        self.run_manager('verify', success=False)
        self.assertTrue(self.pending().exists())
        self.env.pop('TEST_RECONCILE_FAIL')
        self.clear_logs()
        self.run_manager('verify')
        self.assertEqual(self.lines('builds'), [])
        self.assertFalse(self.pending().exists())
        self.assert_no_manifest()

    def test_unchanged_update_verifies_installed_outputs_without_rebuilding(self):
        """Deleted installed files are reported from live checks, without cached metadata."""
        self.run_manager('setup')
        (self.home / '.themes/Hikaide-Light/index.theme').unlink()
        self.clear_logs()
        self.run_manager('update', success=False)
        self.assertEqual(self.lines('builds'), [])
        self.assertIn('installed=no', self.run_manager('status').stdout)
        self.assert_no_manifest()

    def test_legacy_nested_repositories_are_warned_about_and_preserved(self):
        """Retiring nested ownership never moves or deletes a local development tree."""
        legacy = self.repo / 'ecosystem/hikaide-symbols'
        legacy.mkdir(parents=True)
        (legacy / 'personal').write_text('keep')
        result = self.run_manager('status')
        self.assertIn('legacy nested repository detected', result.stderr)
        self.assertEqual((legacy / 'personal').read_text(), 'keep')
        self.assertFalse(self.child('symbols').exists())
        self.assertFalse((self.repo / 'scripts/ecosystem.sh').exists())
        self.assertNotIn('/ecosystem/hikaide-symbols/', (self.repo / '.gitignore').read_text())

    def test_workspace_uses_independent_paths_and_preserves_customization(self):
        """Workspace generation never needs code and leaves existing settings untouched."""
        self.git('init', '-b', 'main', self.repo)
        for component, variable in [('cursor', 'HAKU_CURSOR_SOURCE'), ('gtk', 'HAKU_GTK_THEME_SOURCE'), ('symbols', 'HAKU_ICON_THEME_SOURCE')]:
            self.env[variable] = str(self.remotes[component])
        code = self.binary / 'code'
        code.write_text('#!/bin/sh\ntouch "$HOME/code-called"\nexit 99\n')
        code.chmod(0o755)
        result = self.run_manager('workspace')
        target = self.home / 'HakuSpace.code-workspace'
        required = [str(self.repo), *map(str, self.remotes.values())]
        self.assertEqual(json.loads(target.read_text()), {'folders': [{'path': path} for path in required]})
        self.assertIn('Open with:', result.stdout)
        self.assertFalse((self.home / 'code-called').exists())
        self.assertFalse(self.source_config().exists())
        custom = self.home / 'workspace location/custom.code-workspace'
        self.run_manager('workspace', str(custom))
        document = json.loads(custom.read_text())
        document['settings'] = {'editor.fontSize': 17}
        custom.write_text(json.dumps(document))
        before = custom.read_bytes()
        self.run_manager('workspace', str(custom))
        self.assertEqual(custom.read_bytes(), before)
        custom.write_text('{"folders": [], "settings": {"editor.fontSize": 19}}')
        before = custom.read_bytes()
        self.run_manager('workspace', str(custom), success=False)
        self.assertEqual(custom.read_bytes(), before)



class WallpaperTests(WorkspaceFixture):
    def archive_remote(self):
        """Create a wallpaper-only upstream with no installer entrypoint."""
        remote = self.home / 'wallpaper-remote'
        remote.mkdir()
        self.git('init', '-b', 'main', remote)
        (remote / 'Wallpapers').mkdir()
        (remote / 'Wallpapers/one.jpg').write_bytes(b'wallpaper')
        self.git('-C', remote, 'add', '.')
        self.git('-C', remote, 'commit', '-m', 'wallpapers')
        self.git('config', '--global', f'url.{remote.as_uri()}.insteadOf', 'https://github.com/hakuimaku/hakuspace-archive.git')
        return remote

    def run_assets(self, success=True, *args):
        """Run only the wallpaper entrypoint."""
        result = subprocess.run(['bash', str(self.repo / 'scripts/assets.sh'), *args], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_wallpaper_clone_update_dirty_and_existing_files(self):
        """The archive copies missing media without installing visuals or overwriting files."""
        remote = self.archive_remote()
        self.run_assets()
        destination = self.home / 'Pictures/Wallpapers'
        self.assertEqual((destination / 'one.jpg').read_bytes(), b'wallpaper')
        (destination / 'one.jpg').write_bytes(b'personal wallpaper')
        (remote / 'Wallpapers/two.jpg').write_bytes(b'second')
        self.git('-C', remote, 'add', '.')
        self.git('-C', remote, 'commit', '-m', 'new wallpaper')
        self.run_assets()
        self.assertEqual((destination / 'one.jpg').read_bytes(), b'personal wallpaper')
        self.assertEqual((destination / 'two.jpg').read_bytes(), b'second')
        archive = self.home / 'hakuspace-archive'
        (archive / 'personal').write_text('keep')
        self.run_assets(False)
        self.assertEqual((archive / 'personal').read_text(), 'keep')
        self.assertEqual(self.lines('builds'), [])
        self.assertEqual(self.lines('reconcile'), [])
        self.assertFalse((archive / 'setup.sh').exists())

    def test_wallpaper_override_and_dry_run_do_not_execute_installer(self):
        """Explicit archives are used as-is and setup.sh is never invoked."""
        remote = self.archive_remote()
        (remote / 'setup.sh').write_text('#!/bin/sh\ntouch "$HOME/installer-executed"\nexit 99\n')
        self.env['HAKUSPACE_ARCHIVE_SOURCE'] = str(remote)
        self.run_assets(True, '--dry-run')
        self.assertFalse((self.home / 'Pictures').exists())
        self.run_assets()
        self.assertFalse((self.home / 'installer-executed').exists())
        self.assertFalse((self.home / 'hakuspace-archive').exists())
        self.assertEqual(self.lines('reconcile'), [])


class OrchestratorTests(unittest.TestCase):
    def setUp(self):
        """Replace machine-changing modules with loggers while running real orchestrators."""
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.home = Path(self.work.name)
        self.repo = self.home / 'hakuspace'
        shutil.copytree(ROOT / 'scripts', self.repo / 'scripts')
        for name in ('install.sh', 'update.sh'):
            shutil.copy2(ROOT / name, self.repo / name)
        helpers = self.repo / 'scripts/functions.sh'
        helpers.write_text('''C_BOLD= C_RESET= C_GREEN= C_MAGENTA=
print_header() { :; }
print_divider() { :; }
step_title() { :; }
log_ok() { :; }
log_info() { :; }
log_warn() { echo "$*"; }
log_skip() { :; }
shorten_path() { echo "$1"; }
ask_yes_no() { [[ "$1" != *package* ]]; }
''')
        modules = ('select_wm', 'deploy_mode', 'dependencies', 'packages', 'directories',
                   'once_configs', 'link', 'core', 'legacy_copy', 'setup', 'assets',
                   'state', 'hakucfg', 'shell_setup', 'nixos', 'display_manager', 'desktop_defaults',
                   'reload', 'doctor')
        for name in modules:
            module = self.repo / 'scripts' / (name + '.sh')
            module.write_text('#!/bin/bash\n'
                              f'echo "{name} $*" >> "$TEST_FLOW"\n'
                              + ('echo niri\n' if name == 'select_wm' else '')
                              + ('echo symlink\n' if name == 'deploy_mode' else ''))
            module.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), TEST_FLOW=str(self.home / 'flow'))

    def test_install_separates_visual_sources_and_wallpapers(self):
        """The full installer delegates software and wallpaper setup independently."""
        result = subprocess.run(['bash', str(self.repo / 'install.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        flow = (self.home / 'flow').read_text().splitlines()
        self.assertEqual(flow.count('setup setup'), 1)
        self.assertEqual(flow.count('assets '), 1)
        self.assertLess(flow.index('core --mode symlink'), flow.index('setup setup'))
        self.assertLess(flow.index('setup setup'), flow.index('assets '))

    def test_update_reexec_precedes_ecosystem_and_config_deployment(self):
        """The freshly reexecuted updater checks children before selecting/deploying configs."""
        repo_update = self.repo / 'scripts/repo_update.sh'
        repo_update.write_text('''#!/bin/bash
if [[ ! -f "$HOME/reexecuted" ]]; then
    touch "$HOME/reexecuted"
    echo reexec >> "$TEST_FLOW"
    exit 10
fi
echo updated >> "$TEST_FLOW"
''')
        result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        flow = (self.home / 'flow').read_text().splitlines()
        self.assertEqual(flow[:3], ['reexec', 'updated', 'setup update'])
        self.assertEqual(flow.count('setup update'), 1)
        self.assertLess(flow.index('setup update'), flow.index('select_wm '))
        self.assertLess(flow.index('setup update'), flow.index('core --mode symlink'))
    def test_visual_failure_does_not_block_config_updates_and_returns_failure(self):
        """Visual failure is reported after the remaining updater work completes."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        (self.repo / 'scripts/setup.sh').write_text('#!/bin/sh\necho "setup $*" >> "$TEST_FLOW"\nexit 7\n')
        result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        flow = (self.home / 'flow').read_text().splitlines()
        self.assertIn('core --mode symlink', flow)
        self.assertIn('doctor ', flow)
        self.assertIn('incomplete visual ecosystem update', result.stdout)
        self.assertNotIn('Update complete!', result.stdout)

    def test_optional_workspace_failure_does_not_fail_install(self):
        """A missing or customized workspace cannot block a successful installation."""
        (self.repo / 'scripts/setup.sh').write_text('#!/bin/sh\nif [ "$1" = workspace ]; then exit 9; fi\n')
        result = subprocess.run(['bash', str(self.repo / 'install.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Workspace generation skipped', result.stdout)
        self.assertIn('assets ', (self.home / 'flow').read_text())


if __name__ == '__main__':
    unittest.main()
