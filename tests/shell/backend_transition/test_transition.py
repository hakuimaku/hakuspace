#!/usr/bin/env python3
"""Exercise the deployed backend CLI with disposable process and IPC stubs."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


# One executable fixture models process ownership and records each public action.
STUB = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
import time

root = Path(os.environ["MOCK_ROOT"])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
model_path = root / "model.json"
model = json.loads(model_path.read_text())
backend = (root / "home/.local/state/hakuspace/state/[shell].backend").read_text().strip()

def event(action):
    with (root / "events.jsonl").open("a") as stream:
        stream.write(json.dumps(dict(action=action, backend=backend, phase=model["phase"], args=args)) + "\n")

def save():
    temporary = model_path.with_suffix(".tmp." + str(os.getpid()))
    temporary.write_text(json.dumps(model))
    temporary.replace(model_path)

def finish_quit():
    if model.get("late_kitty_override"):
        path = root / "home/.local/state/hakuspace/theme/kitty-mode.conf"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("background #eeeeee\n")
        event("late-kitty-preview")
    model["phase"] = "finished"
    model["procs"].remove("qs")
    model["owner"] = ""
    event("qs-exit-after-reveal")
    save()

if name in ("pgrep", "pkill"):
    pattern = args[-1]
    matches = [proc for proc in model["procs"]
               if (proc == "qs" and "(qs|quickshell)" in pattern) or proc == pattern]
    if name == "pgrep":
        if "qs" in matches and model["phase"] == "releasing-quit":
            model["polls"] += 1
            if model["polls"] >= 3:
                finish_quit()
                matches = []
            else:
                save()
        if matches:
            print("123")
        sys.exit(0 if matches else 1)
    event("stop:" + pattern)
    if "qs" in matches and model.get("fail") == "ignore-term" and "-KILL" not in args:
        sys.exit(0)
    model["procs"] = [proc for proc in model["procs"] if proc not in matches]
    if model["owner"] in matches:
        model["owner"] = "qs" if "qs" in model["procs"] else ""
    save()
    sys.exit(0)
elif name == "busctl":
    event("notification-owner")
    if not model["owner"]:
        sys.exit(1)
    print("Comm=" + model["owner"])
elif name == "setsid":
    if any("BOOTSTRAP=" in arg for arg in args):
        event("bootstrap")
        assert backend == "classic"
        assert not model["owner"]
        model["procs"].append("qs")
        model["owner"] = "qs"
        model["chrome"] = False
        if model.get("fail") == "swaync-reactivation":
            model["procs"].append("swaync")
            model["owner"] = "swaync"
    else:
        event("supervisor")
        assert "HAKUSPACE_SHELL_TRANSITION_BOOTSTRAP" not in os.environ
        assert backend == "hikai"
        model["procs"].append("qs_supervisor.sh")
    save()
elif name == "qs":
    if args[-1] == "kill":
        event("kill-qs")
        if model.get("fail") == "ignore-term":
            sys.exit(0)
        model["procs"] = [proc for proc in model["procs"] if proc != "qs"]
        model["owner"] = ""
        save()
        sys.exit(0)
    target, method = args[4:6]
    event(target + ":" + method)
    if "qs" not in model["procs"]:
        sys.exit(1)
    if target == "shell":
        if method == "ping":
            print("pong")
        elif method == "quit":
            assert model["phase"] == "finished"
            finish_quit()
        sys.exit(0)
    if method == "status":
        while (root / "pause").exists() and model["phase"] == "covering":
            time.sleep(0.02)
        if model["phase"] in ("covering", "releasing"):
            model["polls"] += 1
            if model["polls"] >= 2 and model.get("fail") != "stall-cover":
                model["phase"] = "covered" if model["phase"] == "covering" else "finished"
                if model.get("fail") == "cover":
                    model["phase"] = "error"
                if model.get("fail") == "crash-cover" and model["phase"] == "covered":
                    model["procs"].remove("qs")
                    model["owner"] = ""
                    model["phase"] = "error"
                event("barrier:" + model["phase"])
            save()
        print(json.dumps(dict(phase=model["phase"], chromeEnabled=model["chrome"])))
    else:
        if model.get("fail") == method:
            model["fail"] = ""
            save()
            print("error:injected")
            sys.exit(0)
        if method == "begin":
            model["phase"] = "covering"
        elif method in ("showChrome", "hideChrome"):
            assert model["phase"] == "covered"
            model["chrome"] = method == "showChrome"
        elif method in ("release", "releaseAndQuit"):
            assert model["phase"] == "covered"
            model["phase"] = "releasing" if method == "release" else "releasing-quit"
        elif method == "cancel":
            model["phase"] = "idle"
        model["polls"] = 0
        save()
        print("ok")
elif name == "swaync":
    event("start-swaync")
    assert "qs" not in model["procs"] and not model["owner"]
    model["procs"].append("swaync")
    model["owner"] = "swaync"
    save()
elif name == "waybar":
    event("waybar:starting")
    if model.get("fail") == "waybar-startup-exit":
        sys.exit(1)
    (root / "waybar.pid").write_text(str(os.getpid()))
    model["procs"].append("waybar")
    save()
    while (root / "pause-waybar").exists() or model.get("fail") == "waybar-startup-stall":
        time.sleep(0.02)
    event("waybar:configured")
    print("Bar configured (width: 1920, height: 28) for output: fixture", flush=True)
    time.sleep(30)
elif name.endswith("_manager.sh"):
    event("manager:" + name)
    if model.get("fail") == name:
        model["fail"] = ""
        save()
        sys.exit(1)
    processes = dict(rounded_screen_manager="rounded_screen.py", edge_trigger_manager="edge_trigger.py",
                     taskbar_manager="taskbar", waybar_manager="waybar",
                     desktop_icons_manager="desktop_icons.py", cava_manager="cava_layer.py")
    proc = processes[name[:-3]]
    if proc not in model["procs"]:
        model["procs"].append(proc)
    save()
elif name == "kitty":
    sys.exit(1)
elif name == "gsettings":
    assert args == ["set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"]
    event("color-scheme:prefer-dark")
elif name == "appearance_ctl.sh":
    assert args == ["apply-mode", "dark"]
    event("appearance:dark")
elif name == "notify-send":
    event("success-notification")
elif name == "gdbus":
    assert args == ["wait", "--session", "--timeout", "10", "org.freedesktop.Notifications"]
    event("wait-notification-server")
    sys.exit(1 if model.get("fail") == "notification-timeout" else 0)
elif name == "hikai_chrome_state_ctl.py":
    event("migrate")
elif name == "opaque_theme.sh":
    assert args[0] == "sync"
    event("opaque:" + args[1])
    if os.environ.get("MOCK_OPAQUE_IMPL"):
        import subprocess
        sys.exit(subprocess.call(["bash", os.environ["MOCK_OPAQUE_IMPL"], *args]))
elif name == "rm":
    assert args == ["-f", "/tmp/cava-layer.pid"]
'''


class BackendTransitionTest(unittest.TestCase):
    """Check real shell ordering, failure returns, state commits, and locking."""

    def setUp(self):
        """Flatten source scripts exactly as deployment does."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "home/.local/bin"
        self.state = self.root / "home/.local/state/hakuspace/state"
        self.bin.mkdir(parents=True)
        self.state.mkdir(parents=True)
        for source in ("sys/haku_backend.sh", "lib/haku_backend_lib.sh", "lib/haku_theme.sh", "lib/haku_state.sh", "lib/haku_state.py",
                       "state/haku_state_migrate.py", "backend/user/hikai_settings_ctl.py", "theme/accent_palette.py", "theme/kitty_theme_ctl.py"):
            shutil.copy2(Path(__file__).resolve().parents[3] / "src/core" / source, self.bin)
        fixture = self.bin / "stub"
        fixture.write_text(STUB)
        fixture.chmod(0o755)
        for name in ("qs", "pgrep", "pkill", "busctl", "setsid", "swaync", "waybar", "rm", "notify-send", "gdbus", "gsettings", "kitty",
                     "opaque_theme.sh", "appearance_ctl.sh", "hikai_chrome_state_ctl.py", "rounded_screen_manager.sh", "edge_trigger_manager.sh",
                     "taskbar_manager.sh", "waybar_manager.sh", "desktop_icons_manager.sh", "cava_manager.sh"):
            (self.bin / name).symlink_to(fixture)
        # Wallpaper resumption is outside the disposable process model.
        wallpaper = self.bin / "wallpaper_resume.sh"
        wallpaper.write_text("#!/bin/sh\nexit 0\n")
        wallpaper.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.root / "home"), MOCK_ROOT=str(self.root),
                        XDG_RUNTIME_DIR=str(self.root / "runtime"), PATH=str(self.bin) + ":" + os.environ["PATH"])
        self.env.pop("HAKUSPACE_SHELL_TRANSITION_BOOTSTRAP", None)

    def prepare(self, backend, fail=""):
        """Seed a healthy old desktop and enable only the required visual checks."""
        (self.state / "[shell].backend").write_text(backend + "\n")
        (self.state / "[desktop].waybar.requested").write_text("1\n")
        model = dict(phase="idle", polls=0, chrome=True, fail=fail,
                     owner="swaync" if backend == "classic" else "qs",
                     procs=["swaync", "waybar", "taskbar", "rounded_screen.py", "edge_trigger.py"]
                     if backend == "classic" else ["qs", "qs_supervisor.sh", "desktop_icons.py", "cava_layer.py"])
        (self.root / "model.json").write_text(json.dumps(model))

    def run_cli(self, *args, success=True):
        """Run the public CLI and retain enough evidence for failed assertions."""
        result = subprocess.run(["bash", str(self.bin / "haku_backend.sh"), *args], env=self.env,
                                capture_output=True, text=True, timeout=45)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def events(self):
        """Read recorded operations with the backend and phase observed at each call."""
        return [json.loads(line) for line in (self.root / "events.jsonl").read_text().splitlines()]

    def assert_order(self, *actions):
        """Require the listed actions in order while allowing readiness polling."""
        remaining = iter(event["action"] for event in self.events())
        for action in actions:
            self.assertIn(action, remaining)

    def assert_backend(self, backend):
        """Verify final state and the matching notification server through the real CLI."""
        self.assertEqual((self.state / "[shell].backend").read_text().strip(), backend)
        self.run_cli("--verify")

    def install_opaque_fixture(self):
        """Exercise real opaque output with inert reload and wallpaper dependencies."""
        source = Path(__file__).resolve().parents[3] / "src/core/theme/opaque_theme.sh"
        implementation = self.bin / "opaque_theme_impl.sh"
        shutil.copy2(source, implementation)
        self.env.update(MOCK_OPAQUE_IMPL=str(implementation), HAKUSPACE_APPLY_STYLE="/usr/bin/true")
        wallpaper = self.bin / "wallpaper_resume.sh"
        wallpaper.write_text("#!/bin/sh\nexit 0\n")
        wallpaper.chmod(0o755)
        (self.state / "[theme].opaque.enabled").write_text("1\n")
        self.preference = self.root / "home/hakucfg/hikai/hikai-shell.json"
        self.preference.parent.mkdir(parents=True, exist_ok=True)
        self.preference.write_text('{"appearance":{"colorMode":"light"}}\n')

    def assert_opaque_context(self, backend):
        """Context synchronization must preserve both requested preferences."""
        self.assertEqual((self.state / "[theme].opaque.enabled").read_text(), "1\n")
        self.assertEqual(self.preference.read_text(), '{"appearance":{"colorMode":"light"}}\n')
        kitty = self.root / "home/.local/state/hakuspace/theme/opaque/kitty.conf"
        self.assertEqual(kitty.read_text().strip(), "background_opacity 1.0" if backend == "classic" else "")

    def test_classic_startup_restores_dark_scheme(self):
        """Classic login resets the desktop preference before showing its applications."""
        self.prepare("classic")
        source = Path(__file__).resolve().parents[3] / "src/core/sys/session_start.sh"
        shutil.copy2(source, self.bin)
        result = subprocess.run(["bash", self.bin / "session_start.sh", "--early"],
                                env=self.env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("color-scheme:prefer-dark", [event["action"] for event in self.events()])

    def test_classic_clears_a_preview_after_the_old_shell_exits(self):
        """A late Light writer cannot leave Classic terminals in the wrong palette."""
        self.prepare("hikai")
        self.install_opaque_fixture()
        model_path = self.root / "model.json"
        model = json.loads(model_path.read_text())
        model["late_kitty_override"] = True
        model_path.write_text(json.dumps(model))
        self.run_cli("set", "classic")
        self.assert_backend("classic")
        override = self.root / "home/.local/state/hakuspace/theme/kitty-mode.conf"
        self.assertEqual(override.read_text(), "")
        self.assert_order("late-kitty-preview", "start-swaync")
        events = self.events()
        late = next(index for index, event in enumerate(events) if event["action"] == "late-kitty-preview")
        self.assertTrue(any(index > late and event["action"] == "appearance:dark" for index, event in enumerate(events)))
        self.assertTrue(any(event["action"] == "appearance:dark" and event["phase"] == "covered" for event in events))

    def test_opaque_roundtrip_preserves_light_preference(self):
        """Both directions synchronize under cover before showing their new shell."""
        self.prepare("classic")
        self.install_opaque_fixture()
        self.run_cli("set", "hikai")
        self.assert_opaque_context("hikai")
        self.run_cli("set", "classic")
        self.assert_opaque_context("classic")
        self.assert_order("barrier:covered", "opaque:hikai", "shellTransition:showChrome",
                          "barrier:finished", "barrier:covered", "opaque:classic", "color-scheme:prefer-dark", "manager:waybar_manager.sh",
                          "shellTransition:releaseAndQuit")
        self.assertTrue(all(event["phase"] == "covered" for event in self.events() if event["action"].startswith("opaque:")))

    def test_opaque_rollback_restores_original_context(self):
        """Failed shell preparation restores opaque output without changing requests."""
        for backend, target, failure in (("classic", "hikai", "cava_manager.sh"),
                                         ("hikai", "classic", "waybar_manager.sh")):
            with self.subTest(backend=backend):
                self.prepare(backend, failure)
                self.install_opaque_fixture()
                self.run_cli("set", target, success=False)
                self.assert_backend(backend)
                self.assert_opaque_context(backend)
                self.assert_order("opaque:" + target, "opaque:" + backend)

    def test_opaque_reload_failure_keeps_recovery_desktop_usable(self):
        """Repeated reload failure must still tear down the cover and restore Classic."""
        self.prepare("classic")
        self.install_opaque_fixture()
        self.env["HAKUSPACE_APPLY_STYLE"] = "/usr/bin/false"
        self.run_cli("set", "hikai", success=False)
        self.assert_backend("classic")
        self.assert_opaque_context("classic")
        self.assert_order("opaque:hikai", "opaque:classic", "kill-qs", "manager:waybar_manager.sh")

    def test_classic_to_hikai(self):
        """No backend commit or Classic teardown may precede full coverage."""
        self.prepare("classic")
        self.run_cli("set", "hikai")
        self.assert_backend("hikai")
        self.assert_order("stop:swaync", "bootstrap", "shellTransition:begin", "barrier:covered",
                          "stop:waybar", "opaque:hikai", "shellTransition:showChrome", "supervisor", "shellTransition:release",
                          "barrier:finished", "success-notification")
        before_cover = self.events()[:next(i for i, e in enumerate(self.events()) if e["action"] == "barrier:covered")]
        self.assertTrue(all(e["backend"] == "classic" for e in before_cover))
        self.assertEqual(next(e for e in self.events() if e["action"] == "supervisor")["backend"], "hikai")
        self.assertEqual(self.run_cli("--check").stdout.strip(), "hikai")

    def test_hikai_to_classic(self):
        """SwayNC starts only after the overlay exits by itself."""
        self.prepare("hikai")
        self.run_cli("--toggle")
        self.assert_backend("classic")
        self.assert_order("shellTransition:begin", "barrier:covered", "stop:qs_supervisor.sh",
                          "shellTransition:hideChrome", "opaque:classic", "manager:waybar_manager.sh",
                          "shellTransition:releaseAndQuit", "qs-exit-after-reveal", "start-swaync", "success-notification")
        self.assertNotIn("kill-qs", [e["action"] for e in self.events()])

    def test_swaync_reactivation_during_bootstrap(self):
        """The loaded notification server retries after Classic reactivates SwayNC."""
        self.prepare("classic", "swaync-reactivation")
        self.run_cli("set", "hikai")
        self.assert_backend("hikai")
        self.assert_order("bootstrap", "stop:swaync", "shellTransition:begin", "barrier:covered")

    def test_hikai_to_classic_reclaims_notifications_before_animation(self):
        """A boot-activated SwayNC must not force an immediate Classic recovery."""
        self.prepare("hikai")
        model_path = self.root / "model.json"
        model = json.loads(model_path.read_text())
        model["owner"] = "swaync"
        model["procs"].append("swaync")
        model_path.write_text(json.dumps(model))
        self.run_cli("set", "classic")
        self.assert_backend("classic")
        self.assert_order("stop:swaync", "shellTransition:begin", "barrier:covered",
                          "shellTransition:releaseAndQuit", "qs-exit-after-reveal", "start-swaync")
        self.assertNotIn("kill-qs", [event["action"] for event in self.events()])

    def test_swaync_activation_follows_backend(self):
        """Systemd activation accepts Classic and refuses Hikai without changing it."""
        source = Path(__file__).resolve().parents[3] / "src/home/.config/systemd/user/swaync.service.d/backend.conf"
        condition = next(line.removeprefix("ExecCondition=") for line in source.read_text().splitlines()
                         if line.startswith("ExecCondition="))
        command = [part.replace("%h", self.env["HOME"]) for part in shlex.split(condition)]
        for backend in ("classic", "hikai"):
            with self.subTest(backend=backend):
                self.prepare(backend)
                result = subprocess.run(command, env=self.env, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0 if backend == "classic" else 1, result.stderr)
                self.assertEqual((self.state / "[shell].backend").read_text().strip(), backend)

    def test_welcome_waits_for_notification_server(self):
        """The login greeting waits for ownership and skips sending after timeout."""
        source = Path(__file__).resolve().parents[3] / "src/core/sys/welcome.sh"
        for failure in ("", "notification-timeout"):
            with self.subTest(failure=failure):
                self.prepare("hikai", failure)
                (self.root / "events.jsonl").write_text("")
                result = subprocess.run(["bash", source], env=dict(self.env, WELCOME_MSG="true"),
                                        capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 1 if failure else 0, result.stderr)
                if failure:
                    self.assertEqual([event["action"] for event in self.events()], ["wait-notification-server"])
                else:
                    self.assert_order("wait-notification-server", "success-notification")

    def install_waybar_controller(self):
        """Exercise the actual Waybar facade/controller behind the shell cutover."""
        (self.bin / "waybar_manager.sh").unlink()
        for source in ("facade/waybar_manager.sh", "backend/desktop/waybar_ctl.sh",
                       "frontend/classic/waybar_rofi.sh"):
            shutil.copy2(Path(__file__).resolve().parents[3] / "src/core" / source, self.bin)
        config = self.root / "home/.config/waybar"
        config.mkdir(parents=True)
        (config / "config").write_text("{}\n")
        (config / "style.css").touch()
        self.addCleanup(self.stop_waybar_fixture)

    def stop_waybar_fixture(self):
        """Stop only the disposable Waybar fixture process."""
        pid_file = self.root / "waybar.pid"
        if pid_file.exists():
            try:
                os.kill(int(pid_file.read_text()), 15)
            except ProcessLookupError:
                pass

    def test_reveal_waits_for_waybar_configuration(self):
        """An alive Waybar and stale log cannot release the black cover early."""
        self.prepare("hikai")
        self.install_waybar_controller()
        runtime = self.root / "runtime/hakuspace"
        runtime.mkdir(parents=True)
        (runtime / "waybar.log").write_text("Bar configured (width: 1, height: 1) for output: stale\n")
        pause = self.root / "pause-waybar"
        pause.touch()
        switch = subprocess.Popen(["bash", str(self.bin / "haku_backend.sh"), "set", "classic"],
                                  env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while not (self.root / "waybar.pid").exists():
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.02)
            time.sleep(0.15)
            self.assertIsNone(switch.poll())
            self.assertNotIn("shellTransition:releaseAndQuit", [e["action"] for e in self.events()])
            self.assertEqual(json.loads((self.root / "model.json").read_text())["phase"], "covered")
        finally:
            pause.unlink()
            stdout, stderr = switch.communicate(timeout=30)
        self.assertEqual(switch.returncode, 0, stdout + stderr)
        self.assert_backend("classic")
        self.assert_order("waybar:starting", "waybar:configured", "shellTransition:releaseAndQuit")

    def test_waybar_startup_failure_rolls_back_before_reveal(self):
        """A failed Waybar process reveals Hikai again instead of incomplete Classic."""
        self.prepare("hikai", "waybar-startup-exit")
        self.install_waybar_controller()
        self.run_cli("set", "classic", success=False)
        self.assert_backend("hikai")
        self.assertNotIn("shellTransition:releaseAndQuit", [e["action"] for e in self.events()])
        self.assert_order("waybar:starting", "shellTransition:showChrome", "shellTransition:release")

    def test_waybar_configuration_timeout_rolls_back(self):
        """An alive Waybar without a configure event cannot leave a permanent cover."""
        self.prepare("hikai", "waybar-startup-stall")
        self.install_waybar_controller()
        self.run_cli("set", "classic", success=False)
        self.assert_backend("hikai")
        self.assertNotIn("shellTransition:releaseAndQuit", [e["action"] for e in self.events()])

    def test_disabled_waybar_does_not_block_reveal(self):
        """A user-disabled Waybar requires no startup acknowledgement."""
        self.prepare("hikai")
        self.install_waybar_controller()
        (self.state / "[desktop].waybar.requested").write_text("0\n")
        self.run_cli("set", "classic")
        self.assert_backend("classic")
        self.assertNotIn("waybar:starting", [e["action"] for e in self.events()])

    def test_precover_failure_preserves_classic_visuals(self):
        """Rejected entry must leave the existing Classic visual stack untouched."""
        self.prepare("classic", "begin")
        self.run_cli("set", "hikai", success=False)
        self.assert_backend("classic")
        self.assertNotIn("stop:waybar", [e["action"] for e in self.events()])
        self.assertNotIn("success-notification", [e["action"] for e in self.events()])

    def test_undercover_hikai_failure_reveals_classic(self):
        """A partial Hikai commit rolls back under cover with the same upward reveal."""
        self.prepare("classic", "cava_manager.sh")
        self.run_cli("set", "hikai", success=False)
        self.assert_backend("classic")
        self.assert_order("barrier:covered", "opaque:classic", "shellTransition:hideChrome", "manager:waybar_manager.sh",
                          "shellTransition:release", "barrier:finished", "shell:quit", "start-swaync")

    def test_undercover_classic_failure_reveals_hikai(self):
        """Classic manager failure restores chrome and the supervisor before release."""
        self.prepare("hikai", "waybar_manager.sh")
        self.run_cli("set", "classic", success=False)
        self.assert_backend("hikai")
        self.assert_order("barrier:covered", "shellTransition:hideChrome", "opaque:classic", "manager:waybar_manager.sh",
                          "shellTransition:showChrome", "supervisor", "shellTransition:release", "barrier:finished")
        self.assertNotIn("start-swaync", [e["action"] for e in self.events()])

    def test_transition_crash_recovers_classic(self):
        """Losing the transition owner must still restore a working notification stack."""
        self.prepare("hikai", "crash-cover")
        self.run_cli("set", "classic", success=False)
        self.assert_backend("classic")

    def test_cover_watchdog_preserves_classic(self):
        """A stalled animation times out without tearing down the old visual stack."""
        self.prepare("classic", "stall-cover")
        self.run_cli("set", "hikai", success=False)
        self.assert_backend("classic")
        self.assertNotIn("stop:waybar", [e["action"] for e in self.events()])

    def test_emergency_kill_of_unresponsive_owner(self):
        """Recovery force-stops an owner that ignores IPC and graceful termination."""
        self.prepare("hikai", "ignore-term")
        self.run_cli("--recover")
        self.assert_backend("classic")
        self.assertTrue(any("-KILL" in event["args"] for event in self.events()))

    def test_recover_and_disabled_classic_features(self):
        """Emergency recovery retains the CLI and respects disabled visual preferences."""
        self.prepare("hikai")
        self.run_cli("--recover")
        self.assert_backend("classic")
        (self.state / "[desktop].waybar.requested").write_text("0\n")
        model = json.loads((self.root / "model.json").read_text())
        model["procs"].remove("waybar")
        (self.root / "model.json").write_text(json.dumps(model))
        self.run_cli("--verify")

    def test_second_toggle_is_rejected(self):
        """A concurrent CLI cannot reverse the in-flight transition."""
        self.prepare("classic")
        pause = self.root / "pause"
        pause.touch()
        first = subprocess.Popen(["bash", str(self.bin / "haku_backend.sh"), "--toggle"], env=self.env,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while json.loads((self.root / "model.json").read_text())["phase"] != "covering":
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.02)
            second = self.run_cli("--toggle", success=False)
            self.assertIn("already running", second.stderr)
        finally:
            pause.unlink()
            stdout, stderr = first.communicate(timeout=30)
        self.assertEqual(first.returncode, 0, stdout + stderr)
        self.assert_backend("hikai")
        self.assertEqual(sum(e["action"] == "shellTransition:begin" for e in self.events()), 1)


if __name__ == "__main__":
    unittest.main()
