#!/usr/bin/env python3
"""Exercise native wallpaper settings, cache safety and real bounded proxy output."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

# Import the controllers without touching the user's settings or media.
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src/core/backend/user"))
import hikai_wallpaper_settings_ctl as settings
spec = importlib.util.spec_from_file_location("wallpaper", ROOT / "src/core/backend/theme/wallpaper_ctl.py")
wallpaper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wallpaper)


class WallpaperTests(unittest.TestCase):
    """Use a private home, state root and artifact cache for every assertion."""

    def setUp(self):
        """Isolate every controller mutation, including compatibility pointers."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        environment = patch.dict(os.environ, HOME=str(self.home), HAKUSPACE_WALLPAPER_SETTINGS_FILE=str(self.home / "settings/wallpaper.json"))
        environment.start()
        self.addCleanup(environment.stop)
        self.cache = self.home / "cache"
        for name, value in {"CACHE": self.cache, "CURRENT": self.home / "state/current.json",
                            "RUNTIME": self.home / "state/runtime.json", "PENDING": self.cache / "pending.json"}.items():
            override = patch.object(wallpaper, name, value)
            override.start()
            self.addCleanup(override.stop)
        self.static = self.home / "Pictures/Wallpapers"
        self.video = self.home / "Videos/Wallpapers"
        self.static.mkdir(parents=True)
        self.video.mkdir(parents=True)
        self.metadata = {"width": 3840, "height": 2160, "fps": 60, "durationMs": 1000, "codec": "h264", "fileSize": 10}

    def test_settings_contract_and_persistence(self):
        """Apply merges a strict patch, while invalid fields never replace saved values."""
        self.assertEqual(settings.run("read")["values"], settings.DEFAULTS)
        self.assertEqual(settings.DEFAULTS["playback"]["profile"], "screen")
        self.assertEqual(settings.DEFAULTS["browser"]["filter"], "static")
        with patch.dict(os.environ, HAKUSPACE_WALLPAPER_SETTINGS_JSON=json.dumps({"playback": {"profile": "original"}})):
            self.assertEqual(settings.run("write")["values"]["playback"]["profile"], "original")
        self.assertEqual(settings.run("read")["values"]["proxy"]["maxCacheMiB"], 4096)
        for patch_value in ({"version": True}, {"playback": {"profile": "tiny"}}, {"proxy": {"maxCacheMiB": True}},
                            {"playback": {"unloadDelaySec": -1}}, {"proxy": {"buildPolicy": "always"}},
                            {"playback": {"hardwareDecode": "cuda"}}, {"browser": {"motionPreview": True}}, {"unknown": {}}):
            with self.subTest(patch_value=patch_value), self.assertRaises(ValueError):
                settings.validate(patch_value, partial=True)
        self.assertEqual(settings.run("read")["values"]["playback"]["profile"], "original")

    def test_legacy_all_filter_opens_images(self):
        """Read the retired filter as Images while retaining the remaining preferences."""
        values = copy.deepcopy(settings.DEFAULTS)
        values["browser"]["filter"] = "all"
        values["playback"]["profile"] = "original"
        path = Path(os.environ["HAKUSPACE_WALLPAPER_SETTINGS_FILE"])
        path.parent.mkdir()
        path.write_text(json.dumps(values))
        loaded = settings.run("read")["values"]
        self.assertEqual(loaded["browser"]["filter"], "static")
        self.assertEqual(loaded["playback"]["profile"], "original")
        self.assertEqual(json.loads(path.read_text()), values)
        with patch.dict(os.environ, HAKUSPACE_WALLPAPER_SETTINGS_JSON=json.dumps({"browser": {"filter": "video"}})):
            self.assertEqual(settings.run("write")["values"]["browser"]["filter"], "video")
        with self.assertRaises(ValueError):
            settings.validate({"browser": {"filter": "all"}}, partial=True)

    def test_settings_reject_symlink(self):
        """A symlink must never redirect a settings write."""
        target = self.home / "victim.json"
        target.write_text(json.dumps(settings.DEFAULTS))
        path = Path(os.environ["HAKUSPACE_WALLPAPER_SETTINGS_FILE"])
        path.parent.mkdir()
        path.symlink_to(target)
        with self.assertRaises(OSError):
            settings.run("read")
        self.assertEqual(json.loads(target.read_text()), settings.DEFAULTS)

    def test_profiles_and_no_upscale(self):
        """Bound Screen to 60 fps and Low Memory to 24 without upscaling sources."""
        self.assertEqual(wallpaper.profile_result(self.metadata, "low-memory"), {"width": 1280, "height": 720, "fps": 24, "needed": True})
        self.assertEqual(wallpaper.profile_result(self.metadata, "screen"), {"width": 1920, "height": 1080, "fps": 60, "needed": True})
        self.assertEqual(wallpaper.profile_result(self.metadata | {"fps": 120}, "screen")["fps"], 60)
        self.assertEqual(wallpaper.profile_result(self.metadata | {"fps": 30}, "screen")["fps"], 30)
        self.assertFalse(wallpaper.profile_result(self.metadata, "screen", 3840, 2160)["needed"])
        original = wallpaper.profile_result(self.metadata, "original")
        self.assertEqual((original["width"], original["height"], original["fps"], original["needed"]), (3840, 2160, 60, False))
        small = self.metadata | {"width": 640, "height": 360, "fps": 20}
        self.assertFalse(wallpaper.profile_result(small, "low-memory")["needed"])
        portrait = wallpaper.profile_result(self.metadata | {"width": 1080, "height": 1920}, "low-memory")
        self.assertEqual((portrait["width"], portrait["height"]), (404, 720))
        with self.assertRaises(ValueError):
            wallpaper.profile_result(self.metadata, "screen", 0, 1080)

    def test_fingerprint_invalidation(self):
        """Source identity and target/profile changes invalidate the cache independently."""
        path = self.video / "source.mp4"
        path.write_bytes(b"first")
        key = wallpaper.proxy_identity(path, "screen", 1920, 1080, self.metadata)
        self.assertEqual(key, wallpaper.proxy_identity(path, "screen", 1920, 1080, self.metadata))
        self.assertNotEqual(key, wallpaper.proxy_identity(path, "screen", 2560, 1440, self.metadata))
        self.assertNotEqual(key, wallpaper.proxy_identity(path, "low-memory", 1920, 1080, self.metadata))
        path.write_bytes(b"second source")
        self.assertNotEqual(key, wallpaper.proxy_identity(path, "screen", 1920, 1080, self.metadata))

    def test_original_does_not_require_proxy_tools(self):
        """Original can reach Qt when external probe tools are unavailable."""
        source = self.video / "original.mp4"
        source.touch()
        with patch.object(wallpaper, "inspect", side_effect=FileNotFoundError("ffprobe")):
            output, metadata, render = wallpaper.ensure_proxy(source, "original", 1920, 1080, False)
            self.assertEqual(output, str(source))
            self.assertFalse(render["needed"])
            with self.assertRaises(FileNotFoundError):
                wallpaper.ensure_proxy(source, "low-memory", 1920, 1080, True)

    def test_discovery_and_thumbnail_cache(self):
        """List both media kinds once and keep generated artifacts out of source folders."""
        (self.static / "forest # 1.png").write_bytes(b"image")
        (self.video / "clip.webm").write_bytes(b"video")
        (self.video / "ignore.txt").touch()
        with patch.object(wallpaper, "thumbnail", return_value="still.jpg"), patch.object(wallpaper, "inspect", return_value=self.metadata):
            items = wallpaper.discover()
            self.assertEqual({item["kind"] for item in items}, {"static", "video"})
            self.assertEqual(len(wallpaper.discover("video")), 1)
            self.assertIn("metadata", next(item for item in items if item["kind"] == "video"))
        self.assertFalse((self.video / ".thumbnails").exists())

    def test_prepare_commit_and_failure_keep_current(self):
        """Current state changes only after an explicit matching readiness token."""
        source = self.static / "wall.png"
        source.write_bytes(b"fixture")
        with patch.object(wallpaper, "thumbnail", return_value=""):
            record = wallpaper.prepare(str(source), "low-memory", 1920, 1080)
        self.assertFalse(wallpaper.CURRENT.exists())
        with self.assertRaises(ValueError):
            wallpaper.commit("stale-token")
        with patch.object(wallpaper.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
            wallpaper.commit(record["token"])
        before = wallpaper.CURRENT.read_bytes()
        with self.assertRaises(FileNotFoundError):
            wallpaper.prepare(str(self.video / "missing.mp4"), "low-memory", 1920, 1080)
        self.assertEqual(wallpaper.CURRENT.read_bytes(), before)
        self.assertEqual((self.home / ".cache/current_wallpaper").read_text().strip(), str(source))

    def test_lru_protects_current_pending_and_building(self):
        """Eviction skips live selections and files with active build locks."""
        proxies = self.cache / "proxies"
        proxies.mkdir(parents=True)
        files = [proxies / (name + ".mp4") for name in ("old", "active", "pending", "building")]
        for file in files:
            file.write_bytes(b"proxy")
        wallpaper.atomic_json(wallpaper.CURRENT, {"proxyPath": str(files[1])})
        wallpaper.atomic_json(wallpaper.PENDING, {"proxyPath": str(files[2])})
        with wallpaper.locked(files[3].with_suffix(".lock")):
            wallpaper.evict(0, clear=True)
            self.assertTrue(all(file.exists() for file in files[1:]))
        self.assertFalse(files[0].exists())

    def test_failed_encoder_cleans_temporary(self):
        """A failing real FFmpeg job cannot publish or retain partial media."""
        if not shutil.which("ffmpeg"):
            self.skipTest("FFmpeg unavailable")
        target = self.home / "broken.mp4"
        with self.assertRaises(ValueError):
            wallpaper.run_ffmpeg(["-i", str(self.home / "missing")], target)
        self.assertFalse(target.exists())
        self.assertFalse(target.with_name("broken.part.mp4").exists())

    def test_real_proxy_atomic_output_and_reuse(self):
        """Real H.264 output is capped, muted, reusable and leaves the original intact."""
        if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
            self.skipTest("FFmpeg unavailable")
        path = self.video / "fixture # clip.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=navy:s=1920x1080:r=60", "-f", "lavfi", "-i", "sine=frequency=440", "-t", "0.4", "-c:v", "libx264", "-preset", "ultrafast", "-threads", "2", "-pix_fmt", "yuv420p", "-c:a", "aac", str(path)], check=True)
        before = wallpaper.fingerprint(path)
        output, metadata, render = wallpaper.ensure_proxy(path, "low-memory", 1920, 1080, True)
        self.assertEqual((render["width"], render["height"], render["fps"]), (1280, 720, 24))
        inspected = wallpaper.inspect(Path(output))
        self.assertEqual((inspected["width"], inspected["height"], inspected["fps"]), (1280, 720, 24))
        streams = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-of", "json", output]))["streams"]
        self.assertEqual([stream["codec_type"] for stream in streams], ["video"])
        self.assertEqual(wallpaper.fingerprint(path), before)
        screen_output, _, screen_render = wallpaper.ensure_proxy(path, "screen", 960, 540, True)
        self.assertEqual((screen_render["width"], screen_render["height"], screen_render["fps"]), (960, 540, 60))
        screen_metadata = wallpaper.inspect(Path(screen_output))
        self.assertEqual((screen_metadata["width"], screen_metadata["height"], screen_metadata["fps"]), (960, 540, 60))
        inode = Path(output).stat().st_ino
        self.assertEqual(wallpaper.ensure_proxy(path, "low-memory", 1920, 1080, False)[0], output)
        self.assertEqual(Path(output).stat().st_ino, inode)
        self.assertFalse(list(self.cache.rglob("*.part.mp4")))
        preview = wallpaper.thumbnail(path)
        self.assertTrue(Path(preview).is_file())
        self.assertEqual(wallpaper.inspect(Path(preview))["width"], 480)
        # A changed cap remains a cache miss under manual build policy.
        with self.assertRaises(ValueError):
            wallpaper.ensure_proxy(path, "screen", 640, 360, False)
        rebuilt = wallpaper.ensure_proxy(path, "low-memory", 1920, 1080, True, rebuild=True)[0]
        self.assertNotEqual(rebuilt, output)
        self.assertTrue(Path(output).exists())
        self.assertEqual(Path(output).stat().st_ino, inode)

    def test_lru_removes_oldest_unused_proxy_first(self):
        """Budget eviction keeps newer entries when the oldest file frees enough space."""
        proxies = self.cache / "proxies"
        proxies.mkdir(parents=True)
        for index, name in enumerate(("old", "new", "active")):
            path = proxies / (name + ".mp4")
            path.write_bytes(b"x" * 1048576)
            os.utime(path, (100 + index, 100 + index))
        wallpaper.atomic_json(wallpaper.CURRENT, {"proxyPath": str(proxies / "active.mp4")})
        self.assertEqual(wallpaper.evict(2), 2 * 1048576)
        self.assertFalse((proxies / "old.mp4").exists())
        self.assertTrue((proxies / "new.mp4").exists())

    def test_concurrent_selection_builds_one_proxy(self):
        """Separate controller processes serialize identical FFmpeg work by cache key."""
        if not shutil.which("ffmpeg"):
            self.skipTest("FFmpeg unavailable")
        source = self.video / "concurrent.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=blue:s=1920x1080:r=60",
                        "-t", "0.3", "-c:v", "libx264", "-preset", "ultrafast", "-threads", "2", str(source)], check=True)
        binary = self.home / "bin"
        binary.mkdir()
        wrapper = binary / "ffmpeg"
        wrapper.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$HOME/ffmpeg.log"\nexec "' + shutil.which("ffmpeg") + '" "$@"\n')
        wrapper.chmod(0o755)
        environment = dict(os.environ, PATH=str(binary) + ":" + os.environ["PATH"], XDG_CACHE_HOME=str(self.home / ".cache"))
        command = [sys.executable, str(ROOT / "src/core/backend/theme/wallpaper_ctl.py"), "select", str(source), "--profile", "low-memory"]
        processes = [subprocess.Popen(command, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
        records = []
        for process in processes:
            output, error = process.communicate(timeout=20)
            self.assertEqual(process.returncode, 0, error)
            records.append(json.loads(output))
        self.assertEqual(records[0]["proxyPath"], records[1]["proxyPath"])
        self.assertEqual(sum("libx264" in line for line in (self.home / "ffmpeg.log").read_text().splitlines()), 1)

    def test_launcher_translates_decoder_policy(self):
        """Only Software overrides Qt's backend choice; unsupported preferences use Auto."""
        binary = self.home / "bin"
        binary.mkdir()
        qs = binary / "qs"
        qs.write_text('#!/bin/bash\nprintf "%s|%s\\n" "${QT_FFMPEG_DECODING_HW_DEVICE_TYPES-unset}" "$*"\n')
        qs.chmod(0o755)
        for mode, expected in (("auto", "unset"), ("prefer", "unset"), ("software", ",")):
            with patch.dict(os.environ, HAKUSPACE_WALLPAPER_SETTINGS_JSON=json.dumps({"playback": {"hardwareDecode": mode}})):
                settings.run("write")
            output = subprocess.check_output([sys.executable, str(ROOT / "src/core/backend/theme/wallpaper_ctl.py"), "launch", "-c", "hakuspace"],
                env=dict(os.environ, PATH=str(binary) + ":" + os.environ["PATH"], QT_FFMPEG_DECODING_HW_DEVICE_TYPES="unavailable"), text=True)
            self.assertEqual(output.strip(), expected + "|-c hakuspace")

    def test_hikai_entrypoints_coordinate_selection_through_ipc(self):
        """Direct callers use coordinated awww/native selection and report busy failures."""
        state = self.home / ".local/state/hakuspace/state"
        state.mkdir(parents=True)
        (state / "[shell].backend").write_text("hikai\n")
        source = self.static / "image # one.png"
        source.touch()
        binary = self.home / "bin"
        binary.mkdir()
        qs = binary / "qs"
        qs.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$HOME/qs.log"\necho "${NATIVE_ACCEPTED:-true}"\n')
        qs.chmod(0o755)
        environment = dict(os.environ, PATH=str(binary) + ":" + os.environ["PATH"])
        script = ROOT / "src/core/theme/wallpaper_set.sh"
        accepted = subprocess.run(["bash", str(script), str(source)], env=environment, capture_output=True)
        self.assertEqual(accepted.returncode, 0, accepted.stderr)
        self.assertIn("ipc call wallpaper select", (self.home / "qs.log").read_text())
        refused = subprocess.run(["bash", str(script), str(source)], env=environment | {"NATIVE_ACCEPTED": "false"}, capture_output=True)
        self.assertEqual(refused.returncode, 1)
        resumed = subprocess.run(["bash", str(ROOT / "src/core/theme/wallpaper_resume.sh")], env=environment, capture_output=True)
        self.assertEqual(resumed.returncode, 0, resumed.stderr)

    def test_hikai_commit_keeps_awww_images_and_generated_caches(self):
        """Apply images with awww, generate both media caches, and retain state on failure."""
        if not shutil.which("ffmpeg") or not shutil.which("magick"):
            self.skipTest("FFmpeg/ImageMagick unavailable")
        binary = self.home / "bin"
        binary.mkdir()
        commands = {
            "awww": 'printf "%s\\n" "$*" >> "$HOME/awww.log"\n[[ "$1" != img || "${AWWW_FAIL:-0}" != 1 ]]',
            "pkill": "exit 0",
            "pgrep": "exit 1",
            "mpvpaper": 'echo unexpected-mpvpaper >> "$HOME/unexpected.log"; exit 1',
            "qs": 'echo unexpected-ipc >> "$HOME/unexpected.log"; exit 1',
        }
        for name, body in commands.items():
            stub = binary / name
            stub.write_text("#!/bin/bash\n" + body + "\n")
            stub.chmod(0o755)
        source = self.static / "image # one.png"
        video = self.video / "native.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=green:s=64x36", "-frames:v", "1", "-threads", "1", str(source)], check=True)
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=navy:s=64x36:r=60", "-t", "0.1", "-c:v", "libx264", "-threads", "1", str(video)], check=True)
        with patch.dict(os.environ, PATH=str(binary) + ":" + os.environ["PATH"], XDG_CURRENT_DESKTOP="labwc"):
            record = wallpaper.prepare(str(source), "screen", 1920, 1080)
            wallpaper.commit(record["token"])
            calls = (self.home / "awww.log").read_text()
            self.assertIn("img " + str(source), calls)
            for name in ("walpaper_wide_gen.jpg", "walpaper_box_gen.jpg"):
                cache = self.home / ".cache" / name
                self.assertTrue(cache.is_file())
                cache.unlink()
            record = wallpaper.prepare(str(video), "screen", 1920, 1080)
            with patch.dict(os.environ, XDG_CURRENT_DESKTOP="niri"):
                wallpaper.commit(record["token"])
            for name in ("walpaper_wide_gen.jpg", "walpaper_box_gen.jpg"):
                self.assertTrue((self.home / ".cache" / name).is_file())
            backdrop_calls = (self.home / "awww.log").read_text()[len(calls):].splitlines()
            self.assertEqual(backdrop_calls, ["query -n awww-daemon-backdrop", "img -n awww-daemon-backdrop --transition-type none " + str(self.home / ".cache/backdrop.jpg")])
            self.assertTrue((self.home / ".cache/backdrop.jpg").is_file())
            self.assertFalse((self.home / "unexpected.log").exists())
            before = wallpaper.CURRENT.read_bytes()
            pointer = (self.home / ".cache/current_wallpaper").read_text()
            with patch.dict(os.environ, AWWW_FAIL="1"):
                record = wallpaper.prepare(str(source), "screen", 1920, 1080)
                with self.assertRaisesRegex(ValueError, "Failed to set image"):
                    wallpaper.commit(record["token"])
            self.assertEqual(wallpaper.CURRENT.read_bytes(), before)
            self.assertEqual((self.home / ".cache/current_wallpaper").read_text(), pointer)

    def test_classic_resume_reapplies_native_compatibility_selection(self):
        """Classic reuses the latest selected image even when its daemon cached an older one."""
        source = self.static / "latest.svg"
        source.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>')
        pointer = self.home / ".cache/current_wallpaper"
        pointer.parent.mkdir()
        pointer.write_text(str(source) + "\n")
        binary = self.home / ".local/bin"
        binary.mkdir(parents=True)
        for name in ("awww", "awww-daemon", "pkill"):
            stub = binary / name
            stub.write_text("#!/bin/bash\nexit 0\n")
            stub.chmod(0o755)
        setter = binary / "wallpaper_set.sh"
        setter.write_text('#!/bin/bash\nprintf "%s\\n" "$1" > "$HOME/resumed.txt"\n')
        setter.chmod(0o755)
        result = subprocess.run(["bash", str(ROOT / "src/core/theme/wallpaper_resume.sh")],
            env=dict(os.environ, PATH=str(binary) + ":" + os.environ["PATH"], XDG_CURRENT_DESKTOP="labwc"), capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "resumed.txt").read_text().strip(), str(source))

    def test_native_random_wallpaper_uses_state_without_mpvpaper(self):
        """Video rotation follows native selection even when no legacy video process exists."""
        state = self.home / ".local/state/hakuspace/state"
        state.mkdir(parents=True)
        (state / "[shell].backend").write_text("hikai\n")
        video = self.video / "rotate.mp4"
        video.touch()
        rotation = self.home / "rotation"
        rotation.write_text("1\n")
        ctl = self.home / "wallpaper_ctl.sh"
        ctl.write_text('#!/bin/bash\nif [[ "$1" == current ]]; then echo \'{"kind":"video"}\'; else printf "%s\\n" "$*" > "$HOME/rotated.txt"; echo 0 > "$STATE_FILE"; fi\n')
        ctl.chmod(0o755)
        source = (ROOT / "src/core/theme/random_wallpaper.sh").read_text()
        function = source[source.index("run_wallpaper() {"):source.index("\ntoggle_wallpaper() {")]
        result = subprocess.run(["bash", "-c", function + "\nrun_wallpaper"], capture_output=True, timeout=5,
            env=dict(os.environ, WALL_INTERVAL="0", STATE_FILE=str(rotation), WALLPAPER_CTL=str(ctl),
                     WALL_DIR=str(self.static), WALL_MPV_DIR=str(self.video)))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "rotated.txt").read_text().strip(), "apply-lively " + str(video))


class WallpaperPanelTests(unittest.TestCase):
    """Render sidebar motion in a private Niri session with fixture thumbnails."""

    @unittest.skipUnless(shutil.which("niri") and os.environ.get("WAYLAND_DISPLAY"),
                         "nested Niri requires a Wayland display")
    def test_slide_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix="hikai-wallpaper-panel-") as temporary:
            work = Path(temporary)
            shell = work / "src/home/.config/quickshell/hakuspace"
            shutil.copytree(ROOT / "src/home/.config/quickshell/hakuspace", shell)
            shutil.copy(ROOT / "scripts/hikai_wallpaper_panel_harness.qml", shell / "shell.qml")
            for name in ("backend", "lib", "theme", "state"):
                shutil.copytree(ROOT / "src/core" / name, work / "src/core" / name)
            home = work / "home"
            images = home / "Pictures/Wallpapers"
            images.mkdir(parents=True)
            subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=steelblue:s=320x180",
                            "-frames:v", "1", "-threads", "1", str(images / "fixture.png")], check=True, timeout=10)
            shutil.copy(images / "fixture.png", images / "second.png")
            runtime = work / "runtime"
            runtime.mkdir(mode=0o700)
            artifacts = Path(os.environ.get("HAKUSPACE_WALLPAPER_PANEL_ARTIFACT_DIR", str(work / "artifacts")))
            artifacts.mkdir(parents=True, exist_ok=True)
            # Resolve only the parent display; all test IPC belongs to the nested compositor.
            display = os.environ["WAYLAND_DISPLAY"]
            if not os.path.isabs(display):
                display = str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
            (work / "niri.kdl").write_text('hotkey-overlay { skip-at-startup; }\n', encoding="utf-8")
            launcher = work / "start.sh"
            shell_log = artifacts / "shell.log"
            launcher.write_text(
                f'quickshell -p {shlex.quote(str(shell))} > {shlex.quote(str(shell_log))} 2>&1\n'
                'niri msg action quit --skip-confirmation\n', encoding="utf-8")
            environment = {key: value for key, value in os.environ.items() if not key.startswith("HAKUSPACE_")}
            environment.update(HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                               XDG_CACHE_HOME=str(home / ".cache"), XDG_RUNTIME_DIR=str(runtime),
                               WAYLAND_DISPLAY=display, XDG_CURRENT_DESKTOP="niri", QT_QPA_PLATFORM="wayland",
                               QSG_INFO="1", HAKUSPACE_WALLPAPER_TEST_NO_HANDOFF="1",
                               HAKUSPACE_WALLPAPER_PANEL_ARTIFACT_DIR=str(artifacts))
            for key in ("DISPLAY", "NIRI_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE", "MANGO_INSTANCE_SIGNATURE",
                        "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6"):
                environment.pop(key, None)
            result = subprocess.run(["dbus-run-session", "--", "niri", "-c", str(work / "niri.kdl"),
                                     "--", "bash", str(launcher)],
                                    env=environment, capture_output=True, text=True, timeout=30)
            log = result.stdout + result.stderr + (shell_log.read_text() if shell_log.exists() else "")
            self.assertEqual(result.returncode, 0, log)
            self.assertIn("Wallpaper panel slide checks passed", log)
            for error in ("TypeError", "ReferenceError", "Binding loop", "Failed to load configuration", "Error decoding"):
                self.assertNotIn(error, log)


if __name__ == "__main__":
    unittest.main()
