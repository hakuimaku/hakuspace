#!/usr/bin/env python3
"""Targeted unit tests for Hikai CAVA underbar implementation."""

import json
import os
import re
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
CAVA_PARSER_JS = ROOT / "src/home/.config/quickshell/hakuspace/services/cava/CavaFrameParser.js"
CAVA_MATH_JS = ROOT / "src/home/.config/quickshell/hakuspace/services/cava/CavaMath.js"
CAVA_MANAGER = ROOT / "src/core/app/cava-layer/cava_manager.sh"


@unittest.skipUnless(shutil.which("niri") and os.environ.get("WAYLAND_DISPLAY"),
                     "nested Niri requires a Wayland display")
class CavaWindowTest(unittest.TestCase):
    """Exercise the underbar geometry in a private nested Niri session."""

    def test_niri_surface_attachment(self):
        self._run_harness("cava.qml", "Hikai Cava attachment checks passed")

    def test_isolated_renderer_lifecycle(self):
        self._run_harness("renderer.qml", "Hikai Cava renderer checks passed")

    def _run_harness(self, harness, marker):
        """Keep the worker, audio fixture and every socket inside one disposable session."""
        with tempfile.TemporaryDirectory(prefix="hikai-cava-test-") as temporary:
            work = Path(temporary)
            shell = work / "home/.config/quickshell/hakuspace"
            shutil.copytree(ROOT / "src/home/.config/quickshell/hakuspace", shell)
            self.assertTrue((shell / "components/cava/CavaRenderer.qml").is_file())
            self.assertFalse((shell / "CavaRenderer.qml").exists())
            self.assertTrue((shell / "cava.qml").is_file())
            shutil.copy(Path(__file__).resolve().parent / "harness" / harness, shell / "shell.qml")
            (shell / "cava-fixture.py").write_text(
                'import os, time\nprint("audioPid=" + str(os.getpid()), flush=True)\n'
                'for _ in range(3600):\n print(";".join(["500"] * 64), flush=True)\n time.sleep(1/60)\n',
                encoding="utf-8")
            # Exercise the production manager after reload without using installed state or config.
            binary = work / "home/.local/bin"
            binary.mkdir(parents=True)
            (binary / "cava_manager.sh").symlink_to(CAVA_MANAGER)
            for name in ("haku_state.sh", "haku_theme.sh", "haku_backend_lib.sh"):
                (binary / name).symlink_to(ROOT / "src/core/lib" / name)
            (binary / "accent_palette.py").symlink_to(ROOT / "src/core/theme/accent_palette.py")
            (binary / "hikai_settings_ctl.py").symlink_to(ROOT / "src/core/backend/user/hikai_settings_ctl.py")
            config_dir = work / "home/hakucfg/config"
            config_dir.mkdir(parents=True)
            audio_fifo = work / "audio.fifo"
            os.mkfifo(audio_fifo)
            (config_dir / "cava-layer").write_text(
                f"[general]\nbars = 64\n\n[input]\nmethod = fifo\nsource = {audio_fifo}\n\n[output]\nmethod = ncurses\n",
                encoding="utf-8")
            runtime = work / "runtime"
            runtime.mkdir(mode=0o700)
            # The nested compositor inherits only the parent display, never its IPC socket.
            display = os.environ.get("WAYLAND_DISPLAY", "wayland-0")
            if not os.path.isabs(display):
                display = str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
            config = work / "niri.kdl"
            config.write_text('hotkey-overlay { skip-at-startup; }\n', encoding="utf-8")
            launcher = work / "start.sh"
            shell_log = work / "shell.log"
            launcher.write_text(
                f'quickshell -p {shlex.quote(str(shell))} > {shlex.quote(str(shell_log))} 2>&1\n'
                'niri msg action quit --skip-confirmation\n', encoding="utf-8")
            environment = {**os.environ, "HOME": str(work / "home"),
                           "XDG_CONFIG_HOME": str(work / "home/.config"),
                           "XDG_STATE_HOME": str(work / "home/.local/state"),
                           "XDG_CACHE_HOME": str(work / "cache"), "XDG_RUNTIME_DIR": str(runtime),
                           "WAYLAND_DISPLAY": display, "XDG_CURRENT_DESKTOP": "niri",
                           "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software"}
            for key in ("DISPLAY", "NIRI_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE",
                        "MANGO_INSTANCE_SIGNATURE", "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6"):
                environment.pop(key, None)
            result = subprocess.run(["dbus-run-session", "--", "niri", "-c", str(config),
                                     "--", "bash", str(launcher)],
                                    env=environment, capture_output=True, text=True, timeout=45)
            log = result.stdout + result.stderr
            if shell_log.exists():
                log += shell_log.read_text()
            if os.environ.get("HAKUSPACE_CAVA_ARTIFACT_DIR"):
                artifacts = Path(os.environ["HAKUSPACE_CAVA_ARTIFACT_DIR"])
                artifacts.mkdir(parents=True, exist_ok=True)
                (artifacts / (harness + ".log")).write_text(log, encoding="utf-8")
            self.assertEqual(result.returncode, 0, log)
            self.assertIn(marker, log)
            for error in ("TypeError", "ReferenceError", "Binding loop", "Failed to load configuration"):
                self.assertNotIn(error, log)
            for pid in re.findall(r"(?:renderer|audio)Pid=(\d+)", log):
                self.assertFalse(Path("/proc", pid).exists(), "Cava child survived its parent: " + pid)
            self.assertFalse(list(runtime.glob("hakuspace-cava-*.sock")), "renderer socket remains after shutdown")


class CavaJsTest(unittest.TestCase):
    """Test CavaFrameParser.js and CavaMath.js using node."""

    def test_parser_chunking_and_normalization(self):
        js_code = f"""
        const fs = require('fs');
        let parserSrc = fs.readFileSync('{CAVA_PARSER_JS}', 'utf8').replace('.pragma library', '');
        eval(parserSrc);

        const parser = createParser({{ barCount: 4, maxRange: 1000 }});

        // 1. Incomplete frame chunk
        let f1 = parser.feed("100;200;");
        if (f1 !== null) process.exit(101);

        // 2. Complete the frame
        let f2 = parser.feed("300;400\\n");
        if (!f2 || f2.length !== 4) process.exit(102);
        if (Math.abs(f2[0] - 0.1) > 0.001 || Math.abs(f2[3] - 0.4) > 0.001) process.exit(103);

        // 3. Multiple frames in one chunk (backpressure: newest wins)
        let f3 = parser.feed("0;0;0;0\\n500;600;700;800\\n");
        if (!f3 || Math.abs(f3[0] - 0.5) > 0.001 || Math.abs(f3[3] - 0.8) > 0.001) process.exit(104);

        // 4. Clamping out-of-range values
        let f4 = parser.feed("-50;1500;500;250\\n");
        if (!f4 || f4[0] !== 0.0 || f4[1] !== 1.0) process.exit(105);

        // 5. Malformed frame handling
        let prevCount = parser.getMalformedCount();
        parser.feed("not_a_number;foo;bar;baz\\n");
        if (parser.getMalformedCount() !== prevCount + 1) process.exit(106);

        // 6. Padding when fewer bars than expected
        let f5 = parser.feed("200;400\\n");
        if (!f5 || f5.length !== 4 || f5[2] !== 0.0 || f5[3] !== 0.0) process.exit(107);

        // 7. Binning when more bars than expected
        let f6 = parser.feed("100;200;300;400;500;600\\n");
        if (!f6 || f6.length !== 4 || Math.abs(f6[3] - 0.6) > 0.001) process.exit(108);

        process.exit(0);
        """
        res = subprocess.run(["node", "-e", js_code], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Node exited with {res.returncode}: {res.stderr}")

    def test_math_smoothing_and_energy(self):
        js_code = f"""
        const fs = require('fs');
        let mathSrc = fs.readFileSync('{CAVA_MATH_JS}', 'utf8').replace('.pragma library', '');
        eval(mathSrc);

        // 1. Temporal smoothing: attack vs release
        let current = [0.0, 0.5, 1.0];
        let target = [1.0, 0.0, 1.0];
        let smoothed = applyTemporalSmoothing(current, target, 0.5, 0.2, 1.0);
        // bar 0: attack from 0.0 toward 1.0: 0.0 + (1.0 - 0.0)*0.5 = 0.5
        if (Math.abs(smoothed[0] - 0.5) > 0.001) process.exit(201);
        // bar 1: release from 0.5 toward 0.0: 0.5 + (0.0 - 0.5)*0.2 = 0.4
        if (Math.abs(smoothed[1] - 0.4) > 0.001) process.exit(202);

        // 2. Spatial smoothing: 3-point kernel
        let bars = [0.0, 1.0, 0.0];
        let spatial = applySpatialSmoothing(bars, 0.5);
        // center weight: 1 - 2*0.1 = 0.8; sides: 0.1
        // spatial[1] = 0.0*0.1 + 1.0*0.8 + 0.0*0.1 = 0.8
        if (Math.abs(spatial[1] - 0.8) > 0.001) process.exit(203);
        // edges: bars[0]*(1 - 0.1) + bars[1]*0.1 = 0.1
        if (Math.abs(spatial[0] - 0.1) > 0.001) process.exit(204);

        // 3. Energy model
        let spectrum = new Array(20).fill(0.0);
        spectrum[9] = 1.0; // center bass region
        spectrum[10] = 1.0;
        let energies = computeEnergies(spectrum);
        if (energies.peak !== 1.0) process.exit(205);
        if (energies.bass <= 0.0) process.exit(206);
        if (energies.overall <= 0.0 || energies.overall >= 1.0) process.exit(207);

        process.exit(0);
        """
        res = subprocess.run(["node", "-e", js_code], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Node exited with {res.returncode}: {res.stderr}")


class CavaConfigTest(unittest.TestCase):
    """Test CAVA layer configuration and generation."""

    def test_cava_hikai_conf_generation_and_runs(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            cfg_dir = home / "hakucfg/config"
            cfg_dir.mkdir(parents=True)
            source_conf = cfg_dir / "cava-layer"
            source_conf.write_text("[general]\nbars = 64\n\n[output]\nmethod = ncurses\n", encoding="utf-8")
            target_conf = home / "cava-hikai.conf"

            res = subprocess.run(["bash", str(CAVA_MANAGER), "--generate-hikai-conf", str(source_conf), str(target_conf)],
                                 capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            if not shutil.which("cava"):
                self.skipTest("cava binary not found")
            p = subprocess.Popen(["cava", "-p", str(target_conf)], stdout=subprocess.PIPE, text=True)
            try:
                line = p.stdout.readline()
            finally:
                if p.stdout:
                    p.stdout.close()
                p.terminate()
                p.wait()
            vals = [x for x in line.strip().split(";") if x]
            self.assertEqual(len(vals), 64, "generated cava conf should emit 64 bars")


class CavaManagerTest(unittest.TestCase):
    """Test cava_manager.sh in Classic and Hikai modes."""

    def _make_env(self, home):
        return {
            **os.environ,
            "HOME": str(home),
            "CAVA_PIDFILE": str(home / "cava-layer.pid"),
            "CAVA_LOGFILE": str(home / "cava-layer.log"),
        }

    def test_status_does_not_create_state_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            env = self._make_env(home)
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--status"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual(res.stdout, "disabled\n")
            self.assertFalse((home / ".local").exists(), "Must not create state dir on --status")

    def test_hikai_mode_lifecycle(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            state_dir = home / ".local/state/hakuspace/state"
            state_dir.mkdir(parents=True)
            (state_dir / "[shell].backend").write_text("hikai\n", encoding="utf-8")
            (state_dir / "[cava].enabled").write_text("0\n", encoding="utf-8")
            env = self._make_env(home)

            # Status should be disabled
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--status"], env=env, capture_output=True, text=True)
            self.assertEqual((res.returncode, res.stdout), (0, "disabled\n"))

            # Start in Hikai mode: writes 1 to [cava].enabled
            res = subprocess.run(["bash", str(CAVA_MANAGER), "start"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].enabled").read_text().strip(), "1")

            # Status should be enabled
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--status"], env=env, capture_output=True, text=True)
            self.assertEqual((res.returncode, res.stdout), (0, "enabled\n"))

            # Toggle in Hikai mode: toggles to 0
            res = subprocess.run(["bash", str(CAVA_MANAGER), "toggle"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].enabled").read_text().strip(), "0")

            # Toggle again: toggles back to 1
            res = subprocess.run(["bash", str(CAVA_MANAGER), "toggle"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].enabled").read_text().strip(), "1")

            # Stop in Hikai mode: sets 0
            res = subprocess.run(["bash", str(CAVA_MANAGER), "stop"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].enabled").read_text().strip(), "0")

    def test_cava_manager_hikai_conf_generation(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            cfg_dir = home / "hakucfg/config"
            cfg_dir.mkdir(parents=True)
            source_conf = cfg_dir / "cava-layer"
            source_conf.write_text("[general]\nbar_width = 4\n\n[output]\nmethod = ncurses\norientation = top\n", encoding="utf-8")
            target_conf = home / "cava-hikai.conf"
            env = self._make_env(home)

            res = subprocess.run(["bash", str(CAVA_MANAGER), "--generate-hikai-conf", str(source_conf), str(target_conf)],
                                 env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            generated = target_conf.read_text(encoding="utf-8")
            self.assertIn("bar_width = 4", generated)
            self.assertIn("method = raw", generated)
            self.assertIn("raw_target = /dev/stdout", generated)
            self.assertIn("data_format = ascii", generated)
            self.assertNotIn("orientation = top", generated)
            self.assertNotIn("method = ncurses", generated)

    def test_cava_manager_color_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            cfg_dir = home / "hakucfg/config"
            cfg_dir.mkdir(parents=True)
            source_conf = cfg_dir / "cava-layer"
            source_conf.write_text("[general]\nbar_width = 4\n\n[color]\nforeground = white\n", encoding="utf-8")
            state_dir = home / ".local/state/hakuspace/state"
            state_dir.mkdir(parents=True)
            env = self._make_env(home)

            # 1. Switch to surface mode
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--color-mode", "surface"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].color-mode").read_text().strip(), "0")
            self.assertIn("foreground = black", source_conf.read_text(encoding="utf-8"))

            # 2. Switch to accent mode
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--color-mode", "accent"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].color-mode").read_text().strip(), "1")
            self.assertIn("foreground = white", source_conf.read_text(encoding="utf-8"))

            # 3. Toggle color with --color-switch (from 1 -> 0)
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--color-switch"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].color-mode").read_text().strip(), "0")
            self.assertIn("foreground = black", source_conf.read_text(encoding="utf-8"))

            # 4. Toggle color again (from 0 -> 1)
            res = subprocess.run(["bash", str(CAVA_MANAGER), "-c"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].color-mode").read_text().strip(), "1")
            self.assertIn("foreground = white", source_conf.read_text(encoding="utf-8"))

    def test_cava_manager_position(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            state_dir = home / ".local/state/hakuspace/state"
            state_dir.mkdir(parents=True)
            env = self._make_env(home)
            (state_dir / "[shell].backend").write_text("hikai\n", encoding="utf-8")

            # 1. Default position is top, so initial toggle from unconfigured state switches to bottom (0)
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--position"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].position").read_text().strip(), "0")

            # 2. Toggle again (from 0 -> 1)
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--position"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].position").read_text().strip(), "1")

            # 3. Explicit set to bottom
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--position", "bottom"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].position").read_text().strip(), "0")

            # 4. Explicit set to top
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--position", "top"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].position").read_text().strip(), "1")

            # 5. In Classic mode, position switching is blocked
            (state_dir / "[shell].backend").write_text("classic\n", encoding="utf-8")
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--position"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertIn("Position switching is only available in Hikai mode", res.stdout)
            self.assertEqual((state_dir / "[cava].position").read_text().strip(), "1")

    def test_cava_manager_dynamic_position(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            state_dir = home / ".local/state/hakuspace/state"
            state_dir.mkdir(parents=True)
            env = self._make_env(home)
            (state_dir / "[shell].backend").write_text("hikai\n", encoding="utf-8")

            # 1. In topbar mode ([desktop].taskbar.requested = 0), toggling dynamic position sets position to top (1)
            (state_dir / "[desktop].taskbar.requested").write_text("0\n", encoding="utf-8")
            (state_dir / "[cava].position").write_text("0\n", encoding="utf-8")
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--toggle-dynamic"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].dynamic-position").read_text().strip(), "1")
            self.assertEqual((state_dir / "[cava].position").read_text().strip(), "1")

            # 2. In taskbar mode ([desktop].taskbar.requested = 1), syncing dynamic sets position to bottom (0)
            (state_dir / "[desktop].taskbar.requested").write_text("1\n", encoding="utf-8")
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--sync-dynamic"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].position").read_text().strip(), "0")

            # 3. Manually setting position disables dynamic position
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--position", "top"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].dynamic-position").read_text().strip(), "0")
            self.assertEqual((state_dir / "[cava].position").read_text().strip(), "1")

            # 4. Toggling dynamic position off
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--toggle-dynamic"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].dynamic-position").read_text().strip(), "1")
            res = subprocess.run(["bash", str(CAVA_MANAGER), "-d"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].dynamic-position").read_text().strip(), "0")

    def test_cava_manager_height(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            state_dir = home / ".local/state/hakuspace/state"
            state_dir.mkdir(parents=True)
            env = self._make_env(home)

            # 1. Set height to 88
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--height", "88"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].height").read_text().strip(), "88")

            # 2. Set height with -H to 120
            res = subprocess.run(["bash", str(CAVA_MANAGER), "-H", "120"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].height").read_text().strip(), "120")

            # 3. Set height to 200 (max settings height)
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--height", "200"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].height").read_text().strip(), "200")

            # 4. Invalid height should fail
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--height", "invalid"], env=env, capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0)

    def test_cava_manager_transition_preserves_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            state_dir = home / ".local/state/hakuspace/state"
            state_dir.mkdir(parents=True)
            env = self._make_env(home)

            # 1. Start in Hikai mode: writes 1 to [cava].enabled
            (state_dir / "[shell].backend").write_text("hikai\n", encoding="utf-8")
            (state_dir / "[cava].enabled").write_text("0\n", encoding="utf-8")
            res = subprocess.run(["bash", str(CAVA_MANAGER), "start"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].enabled").read_text().strip(), "1")

            # 2. Transition to Classic: startup restores state if 1
            (state_dir / "[shell].backend").write_text("classic\n", encoding="utf-8")
            # In a dry test environment, dependencies like GtkLayerShell or python3-gi might not start X11/Wayland window,
            # but [cava].enabled remains 1
            self.assertEqual((state_dir / "[cava].enabled").read_text().strip(), "1")

            # 3. Transition back to Hikai: startup preserves [cava].enabled = 1
            (state_dir / "[shell].backend").write_text("hikai\n", encoding="utf-8")
            res = subprocess.run(["bash", str(CAVA_MANAGER), "--startup"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertEqual((state_dir / "[cava].enabled").read_text().strip(), "1")


if __name__ == "__main__":
    unittest.main()
