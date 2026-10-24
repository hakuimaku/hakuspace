#!/usr/bin/env python3
"""Check runtime boundaries and component runner isolation without starting a desktop."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

# Resolve the checkout while all runner fixtures stay in a temporary directory.
ROOT = Path(__file__).resolve().parents[2]


class TestLayout(unittest.TestCase):
    """Protect the runtime-only scripts directory and portable component entrypoints."""

    def test_runtime_scripts_only(self):
        """Reject test assets, bytecode and developer tools in runtime modules."""
        expected = {
            'assets.sh', 'core.sh', 'dependencies.sh', 'deploy_mode.sh', 'desktop_defaults.sh',
            'directories.sh', 'display_manager.sh', 'doctor.sh', 'filesystem.sh', 'functions.sh',
            'hakucfg.sh', 'legacy_copy.sh', 'link.sh', 'nixos.sh', 'once_configs.sh', 'packages.sh',
            'registry.sh', 'reload.sh', 'repo_update.sh', 'runtime.sh', 'select_wm.sh',
            'shell_setup.sh', 'state.sh', 'unlink.sh', 'variables.sh',
        }
        self.assertEqual({path.name for path in (ROOT / 'scripts').iterdir()}, expected)

    def test_component_runners(self):
        """Run entrypoints from outside the repo, checking command scope and failure returns."""
        runners = sorted((ROOT / 'tests').glob('**/run.sh'))
        self.assertTrue(runners)
        with tempfile.TemporaryDirectory(prefix='hakuspace-runner-test-') as directory:
            temporary = Path(directory)
            binary = temporary / 'bin'
            binary.mkdir()
            for name in ('node', 'python3', 'bash'):
                tool = binary / name
                tool.write_text('#!/bin/sh\nprintf "%s|%s\\n" "$PWD" "$*" >> "$RUNNER_LOG"\n'
                                'exit "${RUNNER_STATUS:-0}"\n')
                tool.chmod(0o755)
            log = temporary / 'commands'
            environment = {**os.environ, 'PATH': str(binary) + ':' + os.environ['PATH'],
                           'RUNNER_LOG': str(log)}
            for runner in runners:
                for arguments in ([], ['--headless' if 'transition' in runner.parts else '--runtime']):
                    with self.subTest(runner=runner.relative_to(ROOT), arguments=arguments):
                        log.write_text('')
                        result = subprocess.run(['/bin/bash', str(runner), *arguments], cwd=temporary,
                                                env=environment, capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        commands = log.read_text().splitlines()
                        self.assertTrue(commands)
                        for command in commands:
                            cwd, arguments_text = command.split('|', 1)
                            self.assertEqual(cwd, str(ROOT))
                            self.assertTrue(arguments_text.startswith(str(runner.parent) + '/'), command)
                with self.subTest(runner=runner.relative_to(ROOT), failure=True):
                    result = subprocess.run(['/bin/bash', str(runner)], cwd=temporary,
                                            env={**environment, 'RUNNER_STATUS': '23'}, capture_output=True)
                    self.assertEqual(result.returncode, 23)
                with self.subTest(runner=runner.relative_to(ROOT), invalid_argument=True):
                    result = subprocess.run(['/bin/bash', str(runner), '--invalid'], cwd=temporary,
                                            env=environment, capture_output=True)
                    self.assertEqual(result.returncode, 2)


if __name__ == '__main__':
    unittest.main()
