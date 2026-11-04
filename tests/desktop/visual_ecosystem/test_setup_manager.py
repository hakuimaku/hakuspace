"""Federated Git, installer and wallpaper contracts using private local remotes."""
import json
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[3]
COMPONENTS = {'cursor': 'haku-cursor', 'gtk': 'hikade-gtk-theme', 'symbols': 'hikaide-symbols'}

# A single cheap upstream fixture exposes each project's supported build/install API.
INSTALLER = r'''import os
from pathlib import Path
import shutil
import signal
import sys
component, action = sys.argv[1:3]
if action == 'build' and os.environ.get('TEST_SIGNAL') and component == 'gtk':
    number = getattr(signal, os.environ['TEST_SIGNAL'])
    os.kill(os.getppid(), number)
    sys.exit(128 + number)
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
if action == 'install' and os.environ.get('TEST_INSTALL_FAIL') == component:
    sys.exit(9)
if action == 'install' and os.environ.get('TEST_BAD_INSTALL') == component:
    sys.exit(0)
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
            path.write_text('''#!/bin/sh
if [ "$1" = selection ]; then
    echo '{"gtk":"Hikaide","icons":"Hikaide-Symbols"}'
    exit 0
fi
printf '%s %s\\n' "$(basename "$0")" "$*" >> "$TEST_RECONCILE"
if [ "${TEST_RECONCILE_FAIL:-0}" = 1 ]; then exit 8; fi
''')
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
                        TEST_GIT_LOG=str(self.home / 'git-calls'), TEST_CLONE_LOG=str(self.home / 'clones'),
                        TMPDIR=str(self.home), TEST_REAL_GIT=shutil.which('git'))
        self.env.pop('XDG_RUNTIME_DIR', None)
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
import json, os, subprocess, sys
from pathlib import Path
with open(os.environ['TEST_GIT_LOG'], 'a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\n')
args = sys.argv[1:]
real = os.environ['TEST_REAL_GIT']
if args[0] == 'clone':
    if os.environ.get('TEST_CLONE_FAIL') and args[-2].endswith('/' + os.environ['TEST_CLONE_FAIL'] + '.git'):
        Path(args[-1]).mkdir()
        (Path(args[-1]) / 'partial').write_text('partial download')
        sys.exit(8)
    result = subprocess.run([real, *args])
    if result.returncode == 0:
        def value(*options):
            return subprocess.check_output([real, '-C', args[-1], *options], text=True).strip()
        with open(os.environ['TEST_CLONE_LOG'], 'a') as log:
            log.write(json.dumps({'path': args[-1], 'head': value('rev-parse', 'HEAD'),
                                  'shallow': value('rev-parse', '--is-shallow-repository')}) + '\n')
    sys.exit(result.returncode)
os.execv(real, ['git', *args])
''')
        wrapper.chmod(0o755)
        self.env['PATH'] = str(self.binary) + ':' + self.env['PATH']

    def git(self, *args):
        """Operate on disposable test history without polluting the manager call log."""
        return subprocess.run([self.env['TEST_REAL_GIT'], *map(str, args)], env=self.env,
                              check=True, text=True, capture_output=True).stdout.strip()

    def run_manager(self, *args, success=True, answers=""):
        """Run the real CLI from outside its checkout."""
        result = subprocess.run(['bash', str(self.repo / 'scripts/setup.sh'), *args],
                                env=self.env, cwd=self.home, text=True, input=answers, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def lines(self, name):
        """Read an optional fixture log."""
        path = self.home / name
        return path.read_text().splitlines() if path.exists() else []

    def clear_logs(self):
        """Separate update effects from the preceding bootstrap."""
        for name in ('builds', 'reconcile', 'git-calls', 'clones'):
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



class ActivationTests(WorkspaceFixture):
    def setUp(self):
        """Use the real appearance controller with local installer fixtures and private settings."""
        super().setUp()
        for name in ('HYPRLAND_INSTANCE_SIGNATURE', 'NIRI_SOCKET', 'MANGO_INSTANCE_SIGNATURE',
                     'WAYLAND_DISPLAY', 'DISPLAY', 'DBUS_SESSION_BUS_ADDRESS', 'XDG_RUNTIME_DIR'):
            self.env.pop(name, None)
        core = self.repo / 'src/core'
        renderer = (core / 'backend/theme/theme_ctl.sh').read_text()
        shutil.copytree(ROOT / 'src/core', core, dirs_exist_ok=True, ignore=shutil.ignore_patterns('__pycache__'))
        (core / 'backend/theme/theme_ctl.sh').write_text(renderer)
        settings = self.binary / 'gsettings'
        settings.write_text('''#!/bin/bash
case "$1" in
    list-schemas) echo org.gnome.desktop.interface ;;
    get)
        selected="$HOME/selected-$3"
        if [[ -f "$selected" ]]; then printf "'%s'\\n" "$(cat "$selected")"; else echo "'Adwaita'"; fi ;;
    set)
        if [[ "${TEST_ACTIVATION_FAIL:-0}" == 1 && "$3" == *-theme && "$3" != cursor-theme ]]; then exit 9; fi
        if [[ "${TEST_ACTIVATION_IGNORE:-0}" != 1 || "$3" == cursor-* ]]; then
            printf '%s\\n' "$4" > "$HOME/selected-$3"
        fi ;;
    *) exit 1 ;;
esac
''')
        settings.chmod(0o755)
        self.configs = []
        for version in ('3.0', '4.0'):
            path = self.home / f'config/gtk-{version}/settings.ini'
            path.parent.mkdir(parents=True)
            path.write_text('[Settings]\n# Personal settings.\ngtk-font-name=Custom Mono 17\n'
                            'gtk-theme-name=Adwaita\ngtk-icon-theme-name=Adwaita\n'
                            '[Unrelated]\ncustom=value\n')
            self.configs.append(path)
        self.backend = self.home / '.local/state/hakuspace/state/[shell].backend'
        self.backend.parent.mkdir(parents=True)
        self.backend.write_text('classic\n')

    def selection(self, key):
        """Read the actual mocked desktop selection independently of installed assets."""
        path = self.home / ('selected-' + key)
        return path.read_text().strip() if path.exists() else 'Adwaita'

    def assert_preserved_settings(self):
        """Native settings keep comments and unrelated preferences without creating CSS overrides."""
        for path in self.configs:
            self.assertIn('# Personal settings.\ngtk-font-name=Custom Mono 17', path.read_text())
            self.assertIn('[Unrelated]\ncustom=value\n', path.read_text())
        for name in ('gtk.css', 'gtk-dark.css'):
            self.assertFalse((self.home / 'config/gtk-4.0' / name).exists())
        self.assertEqual(self.backend.read_text(), 'classic\n')

    def test_fresh_install_activates_only_with_separate_consent(self):
        """Adwaita transitions to installed Hikaide through confirmed GTK and icon activation."""
        result = self.run_manager('setup', answers='y\ny\n')
        self.assertEqual(self.selection('gtk-theme'), 'Hikaide')
        self.assertEqual(self.selection('icon-theme'), 'Hikaide-Symbols')
        for path in self.configs:
            self.assertIn('gtk-theme-name=Hikaide\n', path.read_text())
            self.assertIn('gtk-icon-theme-name=Hikaide-Symbols\n', path.read_text())
        self.assertIn('Appearance applied: GTK=Hikaide; icons=Hikaide-Symbols', result.stdout)
        self.assertIn('Session pending:', result.stdout)
        self.assert_preserved_settings()

    def test_migration_install_uses_the_same_activation_policy(self):
        """The updater's explicit apply entrypoint can install and activate missing families."""
        self.run_manager('apply', 'cursor')
        self.run_manager('apply', 'gtk', answers='y\n')
        self.run_manager('apply', 'symbols', answers='y\n')
        self.assertEqual(self.selection('gtk-theme'), 'Hikaide')
        self.assertEqual(self.selection('icon-theme'), 'Hikaide-Symbols')
        self.assert_preserved_settings()

    def test_declined_activation_preserves_adwaita_and_custom_settings(self):
        """Installing assets alone does not authorize replacing the selected GTK/icon themes."""
        before = [path.read_bytes() for path in self.configs]
        self.run_manager('setup', answers='n\nn\n')
        self.assertEqual(self.selection('gtk-theme'), 'Adwaita')
        self.assertEqual(self.selection('icon-theme'), 'Adwaita')
        self.assertEqual([path.read_bytes() for path in self.configs], before)
        self.assertFalse(self.pending().exists())
        self.assert_preserved_settings()

    def test_external_theme_update_does_not_override_without_consent(self):
        """Later updates preserve deliberate third-party choices independently of managed assets."""
        self.run_manager('setup', answers='y\ny\n')
        (self.home / 'selected-gtk-theme').write_text('User GTK')
        (self.home / 'selected-icon-theme').write_text('User Icons')
        for path in self.configs:
            path.write_text(path.read_text().replace('Hikaide-Symbols', 'User Icons').replace('Hikaide', 'User GTK'))
        before = [path.read_bytes() for path in self.configs]
        self.run_manager('update', answers='n\nn\n')
        self.assertEqual(self.selection('gtk-theme'), 'User GTK')
        self.assertEqual(self.selection('icon-theme'), 'User Icons')
        self.assertEqual([path.read_bytes() for path in self.configs], before)
        self.assert_preserved_settings()

    def test_managed_update_keeps_saved_mode_and_backend(self):
        """Managed Light follows Hikai preferences; activation never writes the backend or preferences."""
        self.run_manager('setup', answers='y\ny\n')
        self.backend.write_text('hikai\n')
        preferences = self.home / 'hakucfg/hikai/hikai-shell.json'
        env = dict(self.env, HAKUSPACE_HIKAI_SETTINGS_JSON=json.dumps({'appearance': {'colorMode': 'light'}}))
        subprocess.run(['python3', '-B', str(self.repo / 'src/core/backend/user/hikai_settings_ctl.py'), 'write'], env=env, check=True, capture_output=True)
        before = preferences.read_bytes()
        self.run_manager('update')
        self.assertEqual(self.selection('gtk-theme'), 'Hikaide-Light')
        self.assertEqual(self.selection('icon-theme'), 'Hikaide-Symbols-Light')
        self.assertEqual(self.backend.read_text(), 'hikai\n')
        self.assertEqual(preferences.read_bytes(), before)

    def test_failed_activation_retries_without_downloading_assets(self):
        """Installed assets survive a gsettings failure and the saved intent resumes without clones."""
        self.env['TEST_ACTIVATION_FAIL'] = '1'
        self.run_manager('setup', success=False, answers='y\ny\n')
        self.assertTrue(self.pending().is_file())
        self.assertEqual(self.pending().read_text().strip(), 'gtk symbols')
        self.assertTrue((self.home / '.themes/Hikaide/index.theme').is_file())
        self.assertTrue((self.home / '.icons/Hikaide-Symbols/index.theme').is_file())
        self.clear_logs()
        self.env.pop('TEST_ACTIVATION_FAIL')
        self.run_manager('update')
        self.assertEqual(self.selection('gtk-theme'), 'Hikaide')
        self.assertEqual(self.selection('icon-theme'), 'Hikaide-Symbols')
        self.assertEqual(self.lines('clones'), [])
        self.assertEqual(self.lines('builds'), [])
        self.assertFalse(self.pending().exists())
        self.assert_preserved_settings()

    def test_system_icon_policy_keeps_observed_selection(self):
        """Explicit system icons stay unmanaged while status reports the real selected name."""
        self.env['HAKU_ICON_THEME'] = 'system'
        result = self.run_manager('setup', answers='y\n')
        self.assertEqual(self.selection('gtk-theme'), 'Hikaide')
        self.assertEqual(self.selection('icon-theme'), 'Adwaita')
        self.assertNotIn('Activate Hikaide-Symbols', result.stderr)
        self.assertIn('icon_theme_selected=Adwaita', self.run_manager('status').stdout)

    def test_invalid_pending_intent_is_rejected_before_download(self):
        """Recovery state accepts only known activation tokens and never executes its contents."""
        self.run_manager('setup', answers='n\nn\n')
        self.pending().write_text('gtk; touch "$HOME/executed"\n')
        self.clear_logs()
        self.run_manager('update', success=False)
        self.assertEqual(self.lines('clones'), [])
        self.assertEqual(self.lines('builds'), [])
        self.assertFalse((self.home / 'executed').exists())

    def test_successful_command_without_selection_change_is_not_activation(self):
        """A backend that ignores successful set calls must leave a failed, retryable activation."""
        self.env['TEST_ACTIVATION_IGNORE'] = '1'
        self.run_manager('setup', success=False, answers='y\ny\n')
        self.assertTrue(self.pending().exists())
        self.assertEqual(self.selection('gtk-theme'), 'Adwaita')


class WorkspaceTests(WorkspaceFixture):
    def test_managed_detection_uses_installer_metadata(self):
        """Recognize installed ownership without downloading or adopting custom themes."""
        self.assertEqual(self.run_manager('managed').stdout.strip(), '')
        for relative, name, raw in (
            ('.icons/Haku-Dark', '.hakuspace-cursor', 'HakuSpace managed cursor v1\n'),
            ('.themes/Hikaide', 'index.theme', '[Desktop Entry]\nGtkTheme=Hikaide\n'),
            ('.icons/Hikaide-Symbols', '.hikaide-symbols.json',
             json.dumps({'family': 'Hikaide-Symbols', 'version': 2, 'variant': 'dark'})),
        ):
            folder = self.home / relative
            folder.mkdir(parents=True)
            (folder / name).write_text(raw)
        self.assertEqual(self.run_manager('managed').stdout.split(), ['cursor', 'gtk', 'symbols'])
        (self.home / '.themes/Hikaide/index.theme').write_text('custom user theme')
        self.assertEqual(self.run_manager('managed').stdout.split(), ['cursor', 'symbols'])
        self.assertEqual(self.clones(), [])

    def clones(self):
        """Read actual clone revisions before their disposable directories disappear."""
        return [json.loads(line) for line in self.lines('clones')]

    def assert_staging_removed(self):
        """Only installation outputs and explicit development sources may remain."""
        self.assertEqual(list(self.home.glob('hakuspace-visuals.*')), [])
        for clone in self.clones():
            self.assertFalse(Path(clone['path']).parent.exists())
        for name in COMPONENTS.values():
            self.assertFalse((self.home / name).exists())
        self.assert_no_manifest()

    def test_default_inspection_creates_no_source_checkouts(self):
        """Read-only inspection reports disposable sources without downloading them."""
        self.assertIn('symbols\ttemporary\tnot retained', self.run_manager('status').stdout)
        self.run_manager('path', 'symbols', success=False)
        self.run_manager('apply', 'unknown', success=False)
        self.assertFalse((self.home / '.local/state').exists())
        self.assert_staging_removed()
        self.assertEqual(self.clones(), [])

    def test_setup_uses_shallow_latest_clones_and_removes_them_after_success(self):
        """Normal setup installs all components without retaining source or history."""
        self.run_manager('setup')
        self.assertEqual(self.lines('builds'), ['cursor', 'gtk', 'symbols'])
        self.assertEqual(len(self.lines('reconcile')), 3)
        self.assertEqual(len(self.clones()), 3)
        for component, clone in zip(COMPONENTS, self.clones()):
            self.assertEqual(clone['shallow'], 'true')
            self.assertEqual(clone['head'], self.git('-C', self.remotes[component], 'rev-parse', 'HEAD'))
        self.assert_staging_removed()
        self.assertFalse(self.source_config().exists())
        self.advance('symbols')
        self.clear_logs()
        self.run_manager('setup')
        self.assertEqual(len(self.clones()), 3)
        self.assertEqual(self.clones()[-1]['head'], self.git('-C', self.remotes['symbols'], 'rev-parse', 'HEAD'))
        self.assert_staging_removed()

    def test_explicit_update_fetches_and_installs_disposable_sources(self):
        """Manual visual update gets latest sources without retaining a source cache."""
        self.run_manager('update')
        self.assertEqual(self.lines('builds'), ['cursor', 'gtk', 'symbols'])
        self.assert_staging_removed()
        self.clear_logs()
        self.run_manager('apply', 'symbols')
        self.assertEqual(self.lines('builds'), ['symbols'])
        self.assertEqual(len(self.clones()), 1)
        self.assert_staging_removed()

    def test_component_verification_is_read_only_and_requires_the_pair(self):
        """Per-component inspection neither retries activation nor requires unrelated assets."""
        self.run_manager('apply', 'gtk')
        self.pending().write_text('gtk\n')
        self.clear_logs()
        self.run_manager('verify', 'gtk')
        self.run_manager('verify', 'cursor', success=False)
        self.run_manager('verify', 'unknown', success=False)
        self.assertEqual(self.pending().read_text(), 'gtk\n')
        self.assertEqual(self.lines('reconcile'), [])
        self.assertEqual(self.clones(), [])
        (self.home / '.themes/Hikaide-Light/index.theme').unlink()
        self.run_manager('verify', 'gtk', success=False)

    def test_dotfile_updates_reuse_installed_visuals_in_new_processes(self):
        """Setup outputs survive source cleanup and repeated updater runs without rebuilding."""
        self.run_manager('setup')
        shutil.copy2(ROOT / 'update.sh', self.repo / 'update.sh')
        for name in ('repo_update', 'packages', 'link', 'migrate', 'nixos',
                     'state', 'hakucfg', 'reload', 'doctor'):
            (self.repo / 'scripts' / (name + '.sh')).write_text('#!/bin/sh\nexit 0\n')
        (self.repo / 'scripts/select_wm.sh').write_text('#!/bin/sh\necho niri\n')
        (self.repo / 'scripts/deploy_mode.sh').write_text('#!/bin/sh\necho symlink\n')
        before = {path: path.read_bytes() for root in (self.home / '.icons', self.home / '.themes')
                  for path in root.rglob('*') if path.is_file()}
        self.clear_logs()
        self.env['TEST_CLONE_FAIL'] = 'haku-cursor'
        for _ in range(2):
            result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                    cwd=self.home, text=True, input='n\ny\ny\ny\ny\n', capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('cursor already installed', result.stdout)
            self.assertIn('gtk already installed', result.stdout)
            self.assertIn('symbols already installed', result.stdout)
            self.assertNotIn('Install/repair visual component', result.stderr)
        self.assertEqual(self.lines('builds'), [])
        self.assertEqual(self.clones(), [])
        self.assertEqual(self.lines('git-calls'), [])
        self.assertEqual(self.lines('reconcile'), ['appearance_ctl.sh verify'] * 2)
        self.assertEqual(before, {path: path.read_bytes() for path in before})

    def test_runtime_directory_is_preferred_for_temporary_sources(self):
        """A private runtime directory takes precedence over TMPDIR."""
        runtime = self.home / 'runtime'
        runtime.mkdir()
        self.env['XDG_RUNTIME_DIR'] = str(runtime)
        self.run_manager('setup')
        self.assertTrue(all(Path(clone['path']).parent.parent == runtime for clone in self.clones()))
        self.assertEqual(list(runtime.iterdir()), [])
        self.assert_staging_removed()

    def test_build_install_and_output_verification_failures_clean_staging(self):
        """Every component failure releases clones while existing installed assets survive."""
        self.run_manager('setup')
        for component in COMPONENTS:
            for failure in ('TEST_FAIL_COMPONENT', 'TEST_INSTALL_FAIL'):
                with self.subTest(component=component, failure=failure):
                    installed = {path: path.read_bytes() for root in (self.home / '.icons', self.home / '.themes')
                                 for path in root.rglob('*') if path.is_file()}
                    self.env[failure] = component
                    self.clear_logs()
                    self.run_manager('setup', success=False)
                    self.assertEqual(installed, {path: path.read_bytes() for path in installed})
                    self.assert_staging_removed()
                    self.env.pop(failure)
        self.env['TEST_BAD_INSTALL'] = 'gtk'
        (self.home / '.themes/Hikaide-Light/index.theme').unlink()
        self.run_manager('setup', success=False)
        self.assert_staging_removed()

    def test_failed_clone_is_removed_and_other_components_are_checked(self):
        """Partial downloads are cleaned without aborting independent installations."""
        self.env['TEST_CLONE_FAIL'] = 'haku-cursor'
        self.run_manager('setup', success=False)
        self.assertEqual(self.lines('builds'), ['gtk', 'symbols'])
        self.assert_staging_removed()
        calls = [json.loads(line) for line in self.lines('git-calls')]
        self.assertEqual(sum(args[0] == 'clone' for args in calls), 3)

    def test_interrupted_setup_removes_only_its_temporary_sources(self):
        """INT and TERM traps clean downloads while local development repositories survive."""
        for signal_name, status in (('SIGINT', 130), ('SIGTERM', 143)):
            with self.subTest(signal=signal_name):
                self.env['TEST_SIGNAL'] = signal_name
                self.clear_logs()
                result = self.run_manager('setup', success=False)
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                self.assert_staging_removed()
                self.assertTrue(all((remote / '.git').is_dir() for remote in self.remotes.values()))
        self.env.pop('TEST_SIGNAL')

    def test_configured_development_sources_are_preserved_without_git_mutation(self):
        """Explicit and remembered local paths are never removed, pulled or reset."""
        paths = {'cursor': self.home / 'a/cursor', 'gtk': self.home / 'b/themes/gtk',
                 'symbols': self.home / 'c symbols'}
        variables = {'cursor': 'HAKU_CURSOR_SOURCE', 'gtk': 'HAKU_GTK_THEME_SOURCE', 'symbols': 'HAKU_ICON_THEME_SOURCE'}
        for component, path in paths.items():
            shutil.copytree(self.remotes[component], path)
            (path / 'personal').write_text('keep')
            self.env[variables[component]] = str(path.relative_to(self.home))
        self.run_manager('setup')
        self.assertEqual(json.loads(self.source_config().read_text()), {key: str(path) for key, path in paths.items()})
        for component, path in paths.items():
            self.assertEqual((path / 'personal').read_text(), 'keep')
            self.env.pop(variables[component])
            self.assertEqual(self.run_manager('path', component).stdout.strip(), str(path))
        self.env['HAKU_ICON_THEME_SOURCE'] = str(self.remotes['symbols'])
        self.assertEqual(self.run_manager('path', 'symbols').stdout.strip(), str(self.remotes['symbols']))
        self.clear_logs()
        result = self.run_manager('update')
        self.assertIn('override, skipped', result.stdout)
        self.assertEqual(self.lines('builds'), [])
        self.run_manager('apply', 'symbols')
        self.assertEqual(self.lines('builds'), ['symbols'])
        self.assertEqual(self.clones(), [])
        calls = [json.loads(line) for line in self.lines('git-calls')]
        self.assertFalse(any(any(command in args for command in ('clone', 'pull', 'reset', 'stash', 'checkout', 'clean')) for args in calls))
        self.assert_staging_removed()
        self.env['TEST_FAIL_COMPONENT'] = 'gtk'
        self.run_manager('apply', 'gtk', success=False)
        self.env.pop('TEST_FAIL_COMPONENT')
        self.env['TEST_SIGNAL'] = 'SIGTERM'
        self.run_manager('setup', success=False)
        for path in paths.values():
            self.assertEqual((path / 'personal').read_text(), 'keep')
            self.assertTrue((path / '.git').is_dir())
        self.assertEqual(self.clones(), [])

    def test_non_git_override_and_missing_override_preserve_local_files(self):
        """Explicit source directories remain usable without being Git-managed or deleted."""
        source = self.home / 'local symbols'
        shutil.copytree(self.remotes['symbols'], source, ignore=shutil.ignore_patterns('.git'))
        (source / 'personal').write_text('keep')
        self.env['HAKU_ICON_THEME_SOURCE'] = str(source)
        self.run_manager('apply', 'symbols')
        self.assertIn('unknown\tdirty=unknown', self.run_manager('status').stdout)
        self.assertEqual((source / 'personal').read_text(), 'keep')
        self.assertFalse((source / '.git').exists())
        self.env['HAKU_ICON_THEME_SOURCE'] = str(self.home / 'missing')
        self.run_manager('apply', 'symbols', success=False)
        self.assertFalse((self.home / 'missing').exists())
        self.assertEqual(self.clones(), [])
        self.assert_no_manifest()

    def test_read_only_commands_ignore_legacy_shell_and_reject_unsafe_state(self):
        """Source intent is inert data and legacy shell configuration never executes."""
        legacy = self.home / 'config/hakuspace/appearance.env'
        legacy.parent.mkdir(parents=True)
        legacy.write_text('touch "$HOME/executed"\nHAKU_CURSOR_SOURCE=/unexpected\n')
        self.run_manager('status')
        self.run_manager('path', 'cursor', success=False)
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
        """Atomic source-state errors retain prior intent and clean temporary state files."""
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
        self.assertTrue(alternate.is_dir())
        self.assert_no_manifest()

    def test_pending_activation_retries_without_downloading_sources(self):
        """An activation retry needs only installed assets after staging is removed."""
        self.env['TEST_RECONCILE_FAIL'] = '1'
        self.run_manager('setup', success=False)
        self.assertTrue(self.pending().exists())
        self.assert_staging_removed()
        self.env.pop('TEST_RECONCILE_FAIL')
        self.clear_logs()
        self.run_manager('update')
        self.assertEqual(self.lines('builds'), [])
        self.assertEqual(self.clones(), [])
        self.assertEqual(len(self.lines('reconcile')), 3)
        self.assertFalse(self.pending().exists())
        self.env['TEST_RECONCILE_FAIL'] = '1'
        self.run_manager('apply', 'gtk', success=False)
        self.assert_staging_removed()
        self.env.pop('TEST_RECONCILE_FAIL')
        self.clear_logs()
        self.run_manager('verify')
        self.assertEqual(self.clones(), [])
        self.assertEqual(self.lines('builds'), [])
        self.assertFalse(self.pending().exists())

    def test_legacy_nested_and_home_development_directories_are_not_deleted(self):
        """New disposable installs do not adopt or remove pre-existing source trees."""
        legacy = self.repo / 'ecosystem/hikaide-symbols'
        legacy.mkdir(parents=True)
        (legacy / 'personal').write_text('keep')
        existing = self.home / 'haku-cursor'
        existing.mkdir()
        (existing / 'personal').write_text('keep')
        result = self.run_manager('setup')
        self.assertIn('legacy nested repository detected', result.stderr)
        self.assertEqual((legacy / 'personal').read_text(), 'keep')
        self.assertEqual((existing / 'personal').read_text(), 'keep')
        self.assertFalse((self.repo / 'scripts/ecosystem.sh').exists())
        self.assertNotIn('/ecosystem/hikaide-symbols/', (self.repo / '.gitignore').read_text())
        self.assertEqual(list(self.home.glob('hakuspace-visuals.*')), [])

    def test_workspace_requires_retained_dev_sources_and_preserves_customization(self):
        """Workspace generation never downloads sources or overwrites customization."""
        self.git('init', '-b', 'main', self.repo)
        self.run_manager('workspace', success=False)
        self.assertFalse((self.home / 'HakuSpace.code-workspace').exists())
        self.assertEqual(self.clones(), [])
        for component, variable in [('cursor', 'HAKU_CURSOR_SOURCE'), ('gtk', 'HAKU_GTK_THEME_SOURCE'), ('symbols', 'HAKU_ICON_THEME_SOURCE')]:
            self.env[variable] = str(self.remotes[component])
        code = self.binary / 'code'
        code.write_text('#!/bin/sh\ntouch "$HOME/code-called"\nexit 99\n')
        code.chmod(0o755)
        self.run_manager('workspace')
        target = self.home / 'HakuSpace.code-workspace'
        required = [str(self.repo), *map(str, self.remotes.values())]
        self.assertEqual(json.loads(target.read_text()), {'folders': [{'path': path} for path in required]})
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
log_error() { echo "$*"; }
log_skip() { :; }
shorten_path() { echo "$1"; }
ask_yes_no() { [[ "$1" != *package* ]]; }
''')
        modules = ('select_wm', 'deploy_mode', 'dependencies', 'packages', 'directories',
                   'once_configs', 'link', 'core', 'legacy_copy', 'setup', 'assets',
                   'state', 'hakucfg', 'shell_setup', 'nixos', 'display_manager', 'desktop_defaults',
                   'reload', 'doctor', 'migrate')
        for name in modules:
            module = self.repo / 'scripts' / (name + '.sh')
            module.write_text('#!/bin/bash\n'
                              f'echo "{name} $*" >> "$TEST_FLOW"\n'
                              + ('echo niri\n' if name == 'select_wm' else '')
                              + ('echo symlink\n' if name == 'deploy_mode' else ''))
            module.chmod(0o755)
        (self.repo / 'scripts/setup.sh').write_text('''#!/bin/bash
echo "setup $*" >> "$TEST_FLOW"
case "$1" in
    managed) echo "${TEST_MANAGED_VISUALS:-}" ;;
    pending) exit "${TEST_ACTIVATION_PENDING:-1}" ;;
    path) exit "${TEST_HAS_OVERRIDE:-1}" ;;
    verify) [[ " ${TEST_INSTALLED_VISUALS:-} " == *" $2 "* ]] ;;
    update|apply) exit "${TEST_VISUAL_FAIL:-0}" ;;
esac
''')
        self.env = dict(os.environ, HOME=str(self.home), TEST_FLOW=str(self.home / 'flow'))

    def test_each_run_logs_both_output_streams_in_a_private_file(self):
        """Both entrypoints retain independent transcripts after their child processes exit."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        (self.repo / 'scripts/doctor.sh').write_text(
            '#!/bin/sh\necho diagnostic-output\necho diagnostic-error >&2\n')
        for operation in ('install', 'update'):
            for _ in range(2):
                result = subprocess.run(['bash', str(self.repo / (operation + '.sh'))], env=self.env,
                                        cwd=self.home, text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('Log file:', result.stdout)
            logs = list((self.repo / 'log').glob(operation + '-*.log'))
            self.assertEqual(len(logs), 2)
            for path in logs:
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                self.assertIn('diagnostic-output', path.read_text())
                self.assertIn('diagnostic-error', path.read_text())
                self.assertIn('COMMAND_EXIT_CODE="0"', path.read_text())

    def test_failed_runs_keep_logs_and_the_original_exit_status(self):
        """Recording must not turn installer or updater failures into success."""
        for operation, module, status in (('install', 'dependencies', 42), ('update', 'repo_update', 19)):
            (self.repo / 'scripts' / (module + '.sh')).write_text(
                f'#!/bin/sh\necho failure-output >&2\nexit {status}\n')
            result = subprocess.run(['bash', str(self.repo / (operation + '.sh'))], env=self.env,
                                    text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, status, result.stdout + result.stderr)
            logs = list((self.repo / 'log').glob(operation + '-*.log'))
            self.assertEqual(len(logs), 1)
            self.assertIn('failure-output', logs[0].read_text())
            self.assertIn(f'COMMAND_EXIT_CODE="{status}"', logs[0].read_text())

    def test_unavailable_log_directory_stops_before_system_changes(self):
        """A failed log setup leaves the installation untouched."""
        (self.repo / 'log').write_text('preserve')
        for operation in ('install', 'update'):
            result = subprocess.run(['bash', str(self.repo / (operation + '.sh'))], env=self.env,
                                    text=True, capture_output=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.repo / 'log').read_text(), 'preserve')
        self.assertFalse((self.home / 'flow').exists())

    def test_recorder_preserves_quoted_paths_arguments_and_shell(self):
        """Recorder command construction treats paths and arguments as literal data."""
        renamed = self.home / "haku space ' $untouched"
        self.repo.rename(renamed)
        self.repo = renamed
        entry = self.repo / 'install.sh'
        entry.write_text('''#!/bin/bash
set -e
HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HAKU_DIR/scripts/run_log.sh"
start_run_log install "$@"
printf 'argument=<%s>\\n' "$@"
printf 'shell=<%s>\\n' "$SHELL"
''')
        self.env['SHELL'] = "/custom shell ' unchanged"
        argument = "spaces ' quotes $(touch $HOME/executed)"
        result = subprocess.run(['bash', str(entry), argument], env=self.env,
                                cwd=self.home, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f'argument=<{argument}>', result.stdout)
        self.assertIn(f'shell=<{self.env["SHELL"]}>', result.stdout)
        self.assertFalse((self.home / 'executed').exists())
        self.assertEqual(len(list((self.repo / 'log').glob('install-*.log'))), 1)

    def test_terminal_prompts_are_logged_without_hidden_password_input(self):
        """A real terminal retains command-substitution menus and non-echoed password reads."""
        shutil.copy2(ROOT / 'scripts/functions.sh', self.repo / 'scripts/functions.sh')
        entry = self.repo / 'install.sh'
        entry.write_text('''#!/bin/bash
set -e
HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HAKU_DIR/scripts/run_log.sh"
start_run_log install "$@"
source "$HAKU_DIR/scripts/functions.sh"
choice="$(ui_prompt 'Choose a WM: ' answer; printf '%s' "$answer")"
[[ "$choice" == niri ]]
stty -echo
ui_printf 'Password: '
IFS= read -r password </dev/tty
stty echo
echo 'Prompt check passed'
''')
        master, slave = pty.openpty()
        process = subprocess.Popen(['bash', str(entry)], env=self.env,
                                   stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = b''
        sent_choice = sent_password = False
        try:
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if not select.select([master], [], [], 0.1)[0]:
                    continue
                try:
                    chunk = os.read(master, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                output += chunk
                if b'Choose a WM: ' in output and not sent_choice:
                    os.write(master, b'niri\n')
                    sent_choice = True
                if b'Password: ' in output and not sent_password:
                    os.write(master, b'private-password-marker\n')
                    sent_password = True
            self.assertEqual(process.wait(timeout=2), 0, output.decode())
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)
        result = subprocess.run(['bash', str(entry)], env=self.env,
                                input='niri\nprivate-password-marker\n',
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        logs = list((self.repo / 'log').glob('install-*.log'))
        self.assertEqual(len(logs), 2)
        for path in logs:
            log = path.read_text()
            self.assertIn('Choose a WM:', log)
            self.assertIn('Password:', log)
            self.assertIn('Prompt check passed', log)
            self.assertNotIn('private-password-marker', log)

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
        self.assertNotIn('setup workspace', flow)

    def test_update_reexec_precedes_deployment_and_visual_opt_in(self):
        """Updated orchestration fetches once and reconciles visuals after deployment."""
        repo_update = self.repo / 'scripts/repo_update.sh'
        repo_update.write_text('''#!/bin/bash
if [[ ! -f "$HOME/reexecuted" ]]; then
    touch "$HOME/reexecuted"
    echo 'Repository refreshed before re-exec'
    echo reexec >> "$TEST_FLOW"
    echo 'registry_format_wm_list() { echo registry-new >> "$TEST_FLOW"; echo "Updated registry loaded" >&2; echo revised; }' >> "$HAKU_DIR/scripts/registry.sh"
    exit 10
fi
echo updated >> "$TEST_FLOW"
''')
        result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        flow = (self.home / 'flow').read_text().splitlines()
        self.assertEqual(flow[:2], ['reexec', 'migrate --plan --to v26.11'])
        self.assertEqual(flow.count('reexec'), 1)
        self.assertNotIn('updated', flow)
        self.assertIn('registry-new', flow)
        self.assertLess(flow.index('reexec'), flow.index('link --all'))
        self.assertIn('setup apply gtk', flow)
        self.assertNotIn('assets ', flow)
        logs = list((self.repo / 'log').glob('update-*.log'))
        self.assertEqual(len(logs), 1)
        transcript = logs[0].read_text()
        self.assertEqual(transcript.count('Repository refreshed before re-exec'), 1)
        self.assertIn('Updated registry loaded', transcript)

    def test_update_skips_developer_override(self):
        """Dotfile updates never rebuild explicitly configured development sources."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        self.env.update(TEST_MANAGED_VISUALS='gtk', TEST_HAS_OVERRIDE='0')
        result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        flow = (self.home / 'flow').read_text().splitlines()
        self.assertFalse(any(line.startswith('setup update') for line in flow))
        self.assertFalse(any(line.startswith('setup apply ') for line in flow))

    def test_installed_visuals_are_skipped_on_repeated_updates(self):
        """Installed files prevent downloads regardless of managed ownership metadata."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        self.env['TEST_INSTALLED_VISUALS'] = 'cursor gtk symbols'
        for managed in ('cursor gtk symbols', ''):
            with self.subTest(managed=managed):
                self.env['TEST_MANAGED_VISUALS'] = managed
                result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        flow = (self.home / 'flow').read_text().splitlines()
        self.assertFalse(any(line.startswith(('setup update', 'setup apply')) for line in flow))
        self.assertEqual(flow.count('setup verify gtk'), 2)
        self.assertEqual(flow.count('setup verify symbols'), 2)

    def test_only_missing_component_is_installed(self):
        """A missing appearance pair can be repaired without reinstalling other components."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        self.env['TEST_INSTALLED_VISUALS'] = 'cursor symbols'
        result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        flow = (self.home / 'flow').read_text().splitlines()
        self.assertEqual([line for line in flow if line.startswith('setup apply ')], ['setup apply gtk'])
        self.assertFalse(any(line.startswith('setup update') for line in flow))

    def test_pending_activation_retry_skips_component_downloads(self):
        """A resumed update reconciles installed assets once instead of fetching each group."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        self.env.update(TEST_ACTIVATION_PENDING='0', TEST_MANAGED_VISUALS='cursor gtk symbols')
        result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        flow = (self.home / 'flow').read_text().splitlines()
        self.assertEqual(flow.count('setup update'), 1)
        self.assertFalse(any(line.startswith(('setup update ', 'setup apply ')) for line in flow))

    def test_visual_failure_blocks_completion(self):
        """Failed visual installation cannot produce a completed migration receipt."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        self.env.update(TEST_MANAGED_VISUALS='gtk', TEST_VISUAL_FAIL='8')
        result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('migrate --complete --to v26.11', (self.home / 'flow').read_text())

    def test_update_failure_never_records_completion(self):
        """A required final failure leaves a resumable migration without a success message."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        (self.repo / 'scripts/doctor.sh').write_text('#!/bin/sh\nexit 7\n')
        result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        flow = (self.home / 'flow').read_text().splitlines()
        self.assertNotIn('migrate --complete --to v26.11', flow)
        self.assertNotIn('Update complete!', result.stdout)
        self.assertIn('PARTIAL / BLOCKED', result.stdout)

    def test_deployment_errors_stop_mutations_and_report_exact_status(self):
        """Failed deployment stops before migration/state/reload but still reports its backup."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        for mode, module, status in (('symlink', 'link', 41), ('copy', 'legacy_copy', 44)):
            with self.subTest(mode=mode):
                flow_file = self.home / 'flow'
                flow_file.unlink(missing_ok=True)
                deployment = self.repo / f'scripts/{module}.sh'
                original = deployment.read_text()
                deployment.write_text(f'#!/bin/bash\necho "{module} $*" >> "$TEST_FLOW"\nexit {status}\n')
                (self.repo / 'scripts/deploy_mode.sh').write_text(f'#!/bin/bash\necho {mode}\n')
                result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                flow = flow_file.read_text()
                self.assertNotIn('migrate --apply', flow)
                self.assertNotIn('migrate --complete', flow)
                self.assertNotIn('state init', flow)
                self.assertNotIn('reload ', flow)
                self.assertIn('PARTIAL / BLOCKED', result.stdout)
                self.assertIn('Backup folder for this update:', result.stdout)
                self.assertNotIn('Update complete!', result.stdout)
                deployment.write_text(original)

    def test_sync_and_reload_errors_continue_diagnostics(self):
        """Recoverable failures retain their status, skip completion and still run doctor."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 0\n')
        (self.repo / 'scripts/doctor.sh').write_text('#!/bin/bash\necho "doctor $*" >> "$TEST_FLOW"\nexit 7\n')
        for module, status in (('state', 31), ('hakucfg', 32), ('reload', 33)):
            with self.subTest(module=module):
                flow_file = self.home / 'flow'
                flow_file.unlink(missing_ok=True)
                failing = self.repo / f'scripts/{module}.sh'
                original = failing.read_text()
                failing.write_text(f'#!/bin/bash\necho "{module} $*" >> "$TEST_FLOW"\nexit {status}\n')
                result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                flow = flow_file.read_text()
                self.assertIn('doctor ', flow)
                self.assertNotIn('migrate --complete', flow)
                if module != 'reload':
                    self.assertNotIn('reload ', flow)
                self.assertIn('PARTIAL / BLOCKED', result.stdout)
                self.assertIn('Backup folder for this update:', result.stdout)
                self.assertNotIn('Update complete!', result.stdout)
                failing.write_text(original)

    def test_update_stops_on_repo_failure(self):
        """Failed Git operations cannot fall through to package or destination changes."""
        (self.repo / 'scripts/repo_update.sh').write_text('#!/bin/sh\nexit 19\n')
        result = subprocess.run(['bash', str(self.repo / 'update.sh')], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 19, result.stdout + result.stderr)
        self.assertFalse((self.home / 'flow').exists())
        self.assertIn('PARTIAL / BLOCKED', result.stdout)
        self.assertIn('Backup folder for this update:', result.stdout)




if __name__ == '__main__':
    unittest.main()
