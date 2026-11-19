#!/usr/bin/env python3
"""Classic mode vertical left AppBar (GTK3 LayerShell + zwlr_foreign_toplevel_manager_v1)."""

import argparse
from dataclasses import dataclass, field
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import urllib.parse

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, GtkLayerShell

try:
    gi.require_version("GLibUnix", "2.0")
    from gi.repository import GLibUnix
except (ValueError, ImportError):
    GLibUnix = None

try:
    gi.require_version("GioUnix", "2.0")
    from gi.repository import GioUnix
except (ValueError, ImportError):
    GioUnix = None

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from wlr_toplevel import WaylandProtocolError, WlrToplevelClient

signal.signal(signal.SIGUSR1, signal.SIG_IGN)

BAR_WIDTH = 48
ICON_SIZE = 28
ARM_TIMEOUT_MS = 3000
TITLE_APP_LIMIT = 6
IGNORE_APP_IDS = {"cavaunderbar", "seycava", "seylavat", "seyclock", "hakuspace-appbar"}
MENU_ICON_NAMES = ("view-app-grid-symbolic", "view-app-grid", "start-here", "gnome-applications")
# Exceed ~/.config/gtk-3.0/gtk.css (PRIORITY_USER) so startup-cached @define-color tokens cannot block hot reload.
APPBAR_CSS_PRIORITY = Gtk.STYLE_PROVIDER_PRIORITY_USER + 1

DEFAULT_PALETTE_CSS = """
@define-color window_bg #455668;
@define-color panel_bg #394656;
@define-color inset_bg #232b34;
@define-color title_bg #3668a0;
@define-color title_fg #f5f7fa;
@define-color text #e8edf3;
@define-color text_muted #c8d4e2;
@define-color border_light #788da5;
@define-color border_dark #14191f;
@define-color border_frame #0c0f12;
@define-color button_bg #4c5f76;
@define-color button_fg #e8edf3;
@define-color button_active_bg #323f4e;
@define-color select_bg #92b5de;
@define-color select_fg #0b1119;
@define-color urgent_bg #952323;
@define-color urgent_fg #ffffff;
"""

APPBAR_CSS = """
* {
    border-radius: 0;
    box-shadow: none;
    text-shadow: none;
    background-image: none;
    transition: none;
}

window#appbar-window {
    background-color: @window_bg;
    color: @text;
}

#appbar-root {
    background-color: @window_bg;
    border-top: 2px solid @border_light;
    border-left: 2px solid @border_light;
    border-right: 2px solid @border_frame;
    border-bottom: 2px solid @border_frame;
    padding: 4px 3px;
}

#appbar-scroll scrollbar {
    opacity: 0;
    min-width: 0;
    min-height: 0;
}

.appbar-sep {
    background-color: @border_dark;
    border-bottom: 1px solid @border_light;
    min-height: 2px;
    margin: 4px 2px;
}

button.appbar-item {
    background-color: @button_bg;
    color: @button_fg;
    border-style: solid;
    border-width: 2px;
    border-color: @border_light @border_dark @border_dark @border_light;
    padding: 8px 2px;
    margin: 2px 0;
    min-height: 36px;
    min-width: 38px;
}

button.appbar-item:hover {
    background-color: @button_active_bg;
}

button.appbar-item.is-active,
button.appbar-item.is-active:hover {
    background-color: @select_bg;
    color: @select_fg;
    border-color: @border_dark @border_light @border_light @border_dark;
}

button.appbar-item.is-system {
    background-color: @title_bg;
    color: @title_fg;
    border-color: @border_light @border_dark @border_dark @border_light;
}

button.appbar-item.is-system:hover {
    background-color: @button_active_bg;
}

button.appbar-item.is-armed,
button.appbar-item.is-armed:hover {
    background-color: @urgent_bg;
    color: @urgent_fg;
    border-color: @border_light @border_dark @border_dark @border_light;
}

button.appbar-item.is-drop-target,
button.appbar-item.is-drop-target:hover {
    background-color: @select_bg;
    color: @select_fg;
    border-color: @border_light @border_dark @border_dark @border_light;
}

.appbar-drop-zone.is-drop-pin {
    border: 2px solid @select_bg;
    background-color: @panel_bg;
}

.appbar-dots {
    min-width: 3px;
}

.appbar-dot {
    min-width: 3px;
    min-height: 4px;
    background-color: @text;
    margin: 1px 0;
}

.appbar-dot.is-active {
    min-height: 14px;
    background-color: @select_fg;
}

.appbar-dot.is-armed {
    background-color: @urgent_fg;
}

.appbar-title {
    font-size: 11px;
    font-weight: bold;
    color: @button_fg;
    margin-top: 3px;
}

button.appbar-item.is-active .appbar-title {
    color: @select_fg;
}

button.appbar-item.is-armed .appbar-title {
    color: @urgent_fg;
}

menu {
    background-color: @panel_bg;
    color: @text;
    border-style: solid;
    border-width: 2px;
    border-color: @border_light @border_dark @border_dark @border_light;
    padding: 3px;
}

menu separator {
    background-color: @border_dark;
    min-height: 2px;
    margin: 3px 2px;
}

menuitem {
    padding: 4px 8px;
    color: @text;
    background-color: transparent;
}

menuitem:hover {
    background-color: @select_bg;
    color: @select_fg;
}

menuitem:disabled label {
    color: @text_muted;
    font-weight: bold;
}

tooltip {
    background-color: @panel_bg;
    color: @text;
    border-style: solid;
    border-width: 2px;
    border-color: @border_light @border_dark @border_dark @border_light;
    padding: 4px 8px;
}

tooltip label {
    color: @text;
}
"""


@dataclass
class AppSlot:
    """Merged representation of a pinned app, running group, or bottom menu button."""

    key: str
    pin_id: str
    desktop_id: str
    app_id: str
    name: str
    icon_spec: object
    desktop_info: object = None
    command: str = ""
    pinned: bool = False
    pin_index: int = -1
    is_system: bool = False
    windows: list = field(default_factory=list)
    active: bool = False


def normalize_id(value):
    """Normalize desktop entry and Wayland app_id strings for matching."""
    return str(value or "").removesuffix(".desktop").lower()


def format_app_title(name):
    """Normalize app name whitespace for vertical label display without truncation."""
    return " ".join(str(name or "").split())


def should_show_titles(pinned_slots, unpinned_slots, limit=TITLE_APP_LIMIT):
    """Show vertical app names on running apps when running app count is at or below limit."""
    running_count = sum(1 for slot in (*pinned_slots, *unpinned_slots) if getattr(slot, "windows", None))
    return running_count <= limit


def resolve_pinned_ctl():
    """Return path to pinned_apps_ctl.py from HAKU_BIN_DIR or repository sibling."""
    bin_dir = Path(os.environ.get("HAKU_BIN_DIR") or (Path.home() / ".local/bin"))
    candidate = bin_dir / "pinned_apps_ctl.py"
    if candidate.is_file():
        return str(candidate)
    return str(Path(__file__).resolve().parents[1] / "shared/pinned_apps_ctl.py")


def resolve_pins_path():
    """Return path to the shared Classic/Hikai taskbar-pin-apps file."""
    return Path(os.environ.get("HAKUSPACE_TASKBAR_PINS_FILE") or (Path.home() / "hakucfg/config/taskbar-pin-apps"))


PIN_ID_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.+\-]*$")


def resolve_desktop_icons_ctl():
    """Return path to desktop_icons_manager.sh from HAKU_BIN_DIR or sibling directory."""
    bin_dir = Path(os.environ.get("HAKU_BIN_DIR") or (Path.home() / ".local/bin"))
    for candidate in (
        bin_dir / "desktop_icons_manager.sh",
        Path(__file__).resolve().parents[1] / "shared/desktop_icons_manager.sh",
    ):
        if candidate.is_file():
            return str(candidate)
    return None


def query_desktop_icons_enabled():
    """Query whether Desktop Icons service is currently enabled."""
    ctl = resolve_desktop_icons_ctl()
    if not ctl:
        return False
    try:
        res = subprocess.run([ctl, "--status"], capture_output=True, text=True, timeout=1.5)
        return res.returncode == 0 and res.stdout.strip().lower() == "enabled"
    except Exception:
        return False


def resolve_slot_desktop_file(slot, search_dirs=None):
    """Locate the backing .desktop file path for an AppSlot, or return None."""
    info = getattr(slot, "desktop_info", None)
    if info is not None and hasattr(info, "get_filename"):
        try:
            fname = info.get_filename()
            if fname and os.path.isfile(fname):
                return fname
        except Exception:
            pass

    candidates = []
    desktop_id = getattr(slot, "desktop_id", "") or ""
    pin_id = getattr(slot, "pin_id", "") or ""
    app_id = getattr(slot, "app_id", "") or ""
    for raw in (desktop_id, pin_id, app_id):
        if not raw:
            continue
        fname = raw if raw.endswith(".desktop") else f"{raw}.desktop"
        if fname not in candidates:
            candidates.append(fname)

    if not candidates:
        return None

    dirs = search_dirs if search_dirs is not None else [
        Path.home() / ".local/share/applications",
        Path("/usr/local/share/applications"),
        Path("/usr/share/applications"),
        Path.home() / ".local/share/flatpak/exports/share/applications",
        Path("/var/lib/flatpak/exports/share/applications"),
    ]
    for directory in dirs:
        base = Path(directory)
        for fname in candidates:
            path = base / fname
            if path.is_file():
                return str(path)
    return None


def parse_drop_uris(uris):
    """Extract local filesystem paths from dropped text/uri-list entries."""
    paths = []
    for raw in uris or ():
        item = str(raw).strip()
        if not item or item.startswith("virtual://"):
            continue
        if item.startswith("file://"):
            path = urllib.parse.unquote(item[7:])
        elif item.startswith("/"):
            path = item
        else:
            continue
        path = path.rstrip("/") or path
        if path and path not in paths:
            paths.append(path)
    return paths


def classify_pin_drop_ids(paths):
    """Split dropped local paths into (valid_desktop_pin_ids, other_file_paths)."""
    pin_ids = []
    other_paths = []
    for path in paths:
        if path.endswith(".desktop"):
            stem = Path(path).name[:-8]
            if stem and PIN_ID_RE.match(stem):
                if stem not in pin_ids:
                    pin_ids.append(stem)
                continue
        other_paths.append(path)
    return pin_ids, other_paths


def compute_show_desktop_plan(toplevels, previously_minimized_handles=None, ignore_ids=IGNORE_APP_IDS):
    """Return (minimize_now, target_handles) for Show Desktop toggling."""
    valid = [t for t in (toplevels or ()) if normalize_id(getattr(t, "app_id", "")) not in ignore_ids]
    unminimized = [t.handle_id for t in valid if not getattr(t, "minimized", False)]
    if unminimized:
        return True, unminimized

    minimized = [t.handle_id for t in valid if getattr(t, "minimized", False)]
    prev = set(previously_minimized_handles or ())
    matching_prev = [hid for hid in minimized if hid in prev]
    return False, (matching_prev if matching_prev else minimized)


def build_classic_css(palette_path=None, fonts_path=None):
    """Combine Classic palette/font tokens with AppBar retro bevel CSS."""
    palette = Path(os.path.expanduser(
        palette_path or os.environ.get("HAKUSPACE_CLASSIC_PALETTE") or "~/.local/state/hakuspace/theme/classic/palette.css"
    ))
    fonts = Path(os.path.expanduser(
        fonts_path or os.environ.get("HAKUSPACE_THEME_FONTS") or "~/.local/state/hakuspace/theme/fonts.css"
    ))
    parts = [DEFAULT_PALETTE_CSS]
    if palette.is_file():
        try:
            parts.append(palette.read_text(encoding="utf-8"))
        except OSError:
            pass
    if fonts.is_file():
        try:
            parts.append(fonts.read_text(encoding="utf-8"))
        except OSError:
            pass
    parts.append(APPBAR_CSS)
    return "\n".join(parts).encode("utf-8")


class DesktopCatalog:
    """Resolve desktop entries and application names/icons from XDG desktop files."""

    def __init__(self, entries=None):
        self._injected = entries is not None
        self._entries = list(entries) if entries is not None else []
        self._by_id = {}
        self._by_wm_class = {}
        self._by_exec = {}
        if not self._injected:
            self.refresh()
        else:
            self._index()

    def refresh(self):
        if self._injected:
            return
        self._entries = list(Gio.AppInfo.get_all())
        self._index()

    def _index(self):
        self._by_id.clear()
        self._by_wm_class.clear()
        self._by_exec.clear()
        for entry in self._entries:
            entry_id = normalize_id(entry.get_id())
            if entry_id and entry_id not in self._by_id:
                self._by_id[entry_id] = entry
            if hasattr(entry, "get_startup_wm_class"):
                wm_class = normalize_id(entry.get_startup_wm_class())
                if wm_class and wm_class not in self._by_wm_class:
                    self._by_wm_class[wm_class] = entry
            exe = entry.get_executable() if hasattr(entry, "get_executable") else ""
            exe_name = Path(exe).name.lower() if exe else ""
            if exe_name and exe_name not in self._by_exec:
                self._by_exec[exe_name] = entry

    def resolve(self, identifier):
        """Match an app_id or pin ID against installed desktop entries."""
        norm = normalize_id(identifier)
        if not norm:
            return None
        for table in (self._by_id, self._by_wm_class, self._by_exec):
            hit = table.get(norm)
            if hit is not None:
                return hit
        # Match reverse-DNS suffix (e.g., zen <-> app.zen_browser.zen, code <-> com.microsoft.VSCode).
        for entry_id, entry in self._by_id.items():
            tail = entry_id.rsplit(".", 1)[-1]
            if tail == norm or norm.endswith("." + tail):
                return entry
        return None


def merge_apps(pins, toplevels, catalog, ignore_ids=IGNORE_APP_IDS):
    """Merge pinned apps with live compositor toplevels; return (pinned, unpinned, menu_slot)."""
    groups = []
    indexed = {}
    for win in toplevels:
        raw_app_id = getattr(win, "app_id", "") or ""
        if normalize_id(raw_app_id) in ignore_ids:
            continue
        entry = catalog.resolve(raw_app_id)
        desktop_id = entry.get_id() if entry else ""
        key = normalize_id(desktop_id or raw_app_id) or f"unknown:{win.handle_id}"
        group = indexed.get(key)
        if group is None:
            name = (entry.get_display_name() or entry.get_name()) if entry else (raw_app_id or getattr(win, "title", "") or "Application")
            icon_spec = entry.get_icon() if entry else (raw_app_id or "application-x-executable")
            pin_id = (desktop_id.removesuffix(".desktop") if desktop_id else raw_app_id) or key
            group = AppSlot(
                key=key,
                pin_id=pin_id,
                desktop_id=desktop_id,
                app_id=raw_app_id,
                name=name,
                icon_spec=icon_spec,
                desktop_info=entry,
            )
            indexed[key] = group
            groups.append(group)
        group.windows.append(win)
        group.active = group.active or bool(getattr(win, "activated", False))

    pinned_slots = []
    menu_slot = None
    represented = set()
    app_pin_index = 0

    for pin in pins:
        pin_id = pin.get("id", "")
        pin_type = pin.get("type", "app")
        command = pin.get("command", "")
        if pin_type == "system" or pin_id == "menu":
            menu_slot = AppSlot(
                key="system:menu",
                pin_id="menu",
                desktop_id="",
                app_id="",
                name="Applications",
                icon_spec=list(MENU_ICON_NAMES),
                command=command,
                pinned=False,
                is_system=True,
            )
            continue

        entry = catalog.resolve(pin_id)
        desktop_id = entry.get_id() if entry else ""
        key = normalize_id(desktop_id or pin_id)
        if not key or key in represented:
            app_pin_index += 1
            continue

        running = next(
            (g for g in groups if g.key == key or normalize_id(g.app_id) == normalize_id(pin_id)),
            None,
        )
        if running is not None:
            key = running.key
            if key in represented:
                app_pin_index += 1
                continue
            represented.add(key)
            pinned_slots.append(
                AppSlot(
                    key=running.key,
                    pin_id=pin_id,
                    desktop_id=running.desktop_id or desktop_id,
                    app_id=running.app_id or pin_id,
                    name=running.name,
                    icon_spec=running.icon_spec,
                    desktop_info=running.desktop_info or entry,
                    command=command,
                    pinned=True,
                    pin_index=app_pin_index,
                    windows=list(running.windows),
                    active=running.active,
                )
            )
        else:
            represented.add(key)
            name = (entry.get_display_name() or entry.get_name()) if entry else pin_id
            icon_spec = entry.get_icon() if entry else (pin_id or "application-x-executable")
            pinned_slots.append(
                AppSlot(
                    key=key,
                    pin_id=pin_id,
                    desktop_id=desktop_id,
                    app_id=pin_id,
                    name=name,
                    icon_spec=icon_spec,
                    desktop_info=entry,
                    command=command,
                    pinned=True,
                    pin_index=app_pin_index,
                )
            )
        app_pin_index += 1

    if menu_slot is None:
        menu_slot = AppSlot(
            key="system:menu",
            pin_id="menu",
            desktop_id="",
            app_id="",
            name="Applications",
            icon_spec=list(MENU_ICON_NAMES),
            command="$HOME/.local/bin/hakumenu.sh",
            is_system=True,
        )

    unpinned_slots = [g for g in groups if g.key not in represented]
    return pinned_slots, unpinned_slots, menu_slot


def next_window_to_activate(windows, previous_handle=None):
    """Cycle through windows of an app, matching DockAppModel.nextWindow()."""
    if not windows:
        return None
    active_idx = next((idx for idx, win in enumerate(windows) if win.activated), -1)
    if active_idx < 0 and previous_handle is not None:
        active_idx = next((idx for idx, win in enumerate(windows) if win.handle_id == previous_handle), -1)
    return windows[(active_idx + 1) % len(windows)]


class AppBarController:
    """Own Wayland connection, pin sync, CSS theme, and per-monitor LayerShell windows."""

    def __init__(self, bar_width=BAR_WIDTH, icon_size=ICON_SIZE):
        self.bar_width = bar_width
        self.icon_size = icon_size
        self.catalog = DesktopCatalog()
        self.pins_path = resolve_pins_path()
        self.pinned_ctl = resolve_pinned_ctl()
        self.pins = []
        self.focused_handles = {}
        self._show_desktop_handles = set()
        self.armed_key = None
        self._arm_timer_id = 0
        self._pin_reload_timer = 0
        self._windows = {}
        self._pixbuf_cache = {}
        self._css_provider = Gtk.CssProvider()

        self._setup_theme_watchers()
        self.reload_css()

        self.wlr = WlrToplevelClient(
            on_change=self._on_toplevels_changed,
            on_disconnect=self._on_wayland_disconnect,
        )
        self.wlr.connect()
        GLib.io_add_watch(self.wlr.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self._on_wayland_io)

        self._setup_pin_monitor()
        self._load_pins_sync()
        self._setup_monitors()
        self.rebuild_ui()

    def _setup_theme_watchers(self):
        self.icon_theme = Gtk.IconTheme.get_default()
        self.icon_theme.connect("changed", self._on_icon_theme_changed)
        source = Gio.SettingsSchemaSource.get_default()
        schema = source.lookup("org.gnome.desktop.interface", True) if source else None
        self._gsettings = Gio.Settings.new_full(schema, None, None) if schema else None
        if self._gsettings:
            self._gsettings.connect("changed::icon-theme", self._on_icon_theme_changed)
        self._app_monitor = Gio.AppInfoMonitor.get()
        self._app_monitor.connect("changed", self._on_apps_changed)

    def _on_icon_theme_changed(self, *args):
        self._pixbuf_cache.clear()
        self.rebuild_ui()

    def _on_apps_changed(self, *args):
        self.catalog.refresh()
        self._pixbuf_cache.clear()
        self.rebuild_ui()

    def reload_css(self):
        screen = Gdk.Screen.get_default()
        if not screen:
            return
        try:
            new_provider = Gtk.CssProvider()
            new_provider.load_from_data(build_classic_css())
            if self._css_provider is not None:
                Gtk.StyleContext.remove_provider_for_screen(screen, self._css_provider)
            self._css_provider = new_provider
            Gtk.StyleContext.add_provider_for_screen(
                screen, self._css_provider, APPBAR_CSS_PRIORITY
            )
            Gtk.StyleContext.reset_widgets(screen)
        except GLib.Error as err:
            print(f"[appbar-layer] Failed loading CSS: {err}", file=sys.stderr)
        self._pixbuf_cache.clear()
        if self._windows:
            self.rebuild_ui()
            for win_info in self._windows.values():
                win_info["window"].queue_draw()
        print("[appbar-layer] Reloaded Classic CSS", flush=True)

    def _setup_pin_monitor(self):
        parent = self.pins_path.parent
        parent.mkdir(parents=True, exist_ok=True)
        try:
            self._pin_monitor = Gio.File.new_for_path(str(parent)).monitor_directory(Gio.FileMonitorFlags.NONE, None)
            self._pin_monitor.connect("changed", self._on_pin_dir_changed)
        except GLib.Error as err:
            print(f"[appbar-layer] Could not watch {parent}: {err}", file=sys.stderr)
            self._pin_monitor = None

    def _on_pin_dir_changed(self, monitor, file, other_file, event_type):
        if file and file.get_basename() != self.pins_path.name:
            return
        if event_type in (
            Gio.FileMonitorEvent.CHANGED,
            Gio.FileMonitorEvent.CHANGES_DONE_HINT,
            Gio.FileMonitorEvent.CREATED,
            Gio.FileMonitorEvent.MOVED_IN,
            Gio.FileMonitorEvent.DELETED,
        ):
            if not self._pin_reload_timer:
                self._pin_reload_timer = GLib.timeout_add(80, self._reload_pins_debounced)

    def _reload_pins_debounced(self):
        self._pin_reload_timer = 0
        self._load_pins_async()
        return GLib.SOURCE_REMOVE

    def _load_pins_sync(self):
        if not self.pins_path.exists():
            self.pins = []
            return
        try:
            res = subprocess.run(
                [sys.executable, self.pinned_ctl, "list"],
                capture_output=True,
                text=True,
                timeout=2,
            )
            if res.returncode == 0:
                parsed = json.loads(res.stdout)
                if isinstance(parsed, list):
                    self.pins = parsed
        except (OSError, ValueError, subprocess.SubprocessError) as err:
            print(f"[appbar-layer] Could not read pins: {err}", file=sys.stderr)

    def _load_pins_async(self):
        self._run_pin_cmd(["list"])

    def _run_pin_cmd(self, args):
        try:
            proc = Gio.Subprocess.new(
                [sys.executable, self.pinned_ctl, *args],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
            )
        except GLib.Error as err:
            print(f"[appbar-layer] Pin command failed: {err}", file=sys.stderr)
            return
        proc.communicate_utf8_async(None, None, self._on_pin_cmd_done)

    def _on_pin_cmd_done(self, proc, result):
        try:
            ok, stdout, stderr = proc.communicate_utf8_finish(result)
            if proc.get_successful() and stdout:
                parsed = json.loads(stdout)
                if isinstance(parsed, list):
                    self.pins = parsed
                    self.rebuild_ui()
            elif stderr:
                print(f"[appbar-layer] {stderr.strip()}", file=sys.stderr)
        except (GLib.Error, ValueError) as err:
            print(f"[appbar-layer] Pin parse error: {err}", file=sys.stderr)

    def _on_wayland_io(self, source, condition):
        if condition & (GLib.IO_HUP | GLib.IO_ERR):
            self._on_wayland_disconnect(WaylandProtocolError("Wayland connection closed"))
            return GLib.SOURCE_REMOVE
        return self.wlr.read_and_dispatch()

    def _on_wayland_disconnect(self, err):
        print(f"[appbar-layer] Disconnected from Wayland: {err}", file=sys.stderr)
        self.cleanup()

    def _on_toplevels_changed(self, toplevels):
        self.rebuild_ui()

    def _setup_monitors(self):
        display = Gdk.Display.get_default()
        display.connect("monitor-added", self._on_monitor_added)
        display.connect("monitor-removed", self._on_monitor_removed)
        for index in range(display.get_n_monitors()):
            self._add_monitor_window(display.get_monitor(index))

    def _on_monitor_added(self, display, monitor):
        self._add_monitor_window(monitor)
        self.rebuild_ui()

    def _on_monitor_removed(self, display, monitor):
        win = self._windows.pop(monitor, None)
        if win is not None:
            win["window"].destroy()

    def _add_monitor_window(self, monitor):
        win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        win.set_name("appbar-window")
        win.set_title("HakuSpace AppBar")
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_border_width(0)

        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_namespace(win, "hakuspace-appbar")
        GtkLayerShell.set_monitor(win, monitor)
        GtkLayerShell.set_layer(win, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_exclusive_zone(win, self.bar_width)
        GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)
        win.set_size_request(self.bar_width, -1)

        root_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        root_box.set_name("appbar-root")

        scroll = Gtk.ScrolledWindow()
        scroll.set_name("appbar-scroll")
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_propagate_natural_height(False)
        scroll.set_vexpand(True)

        list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        list_box.get_style_context().add_class("appbar-drop-zone")
        list_box.drag_dest_set(Gtk.DestDefaults.DROP, [], Gdk.DragAction.COPY | Gdk.DragAction.MOVE)
        list_box.drag_dest_add_uri_targets()
        list_box.connect("drag-motion", self._on_list_drag_motion)
        list_box.connect("drag-leave", self._on_list_drag_leave)
        list_box.connect("drag-data-received", self._on_list_drag_data_received)
        scroll.add(list_box)

        bottom_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)

        root_box.pack_start(scroll, True, True, 0)
        root_box.pack_end(bottom_box, False, False, 0)
        win.add(root_box)
        win.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        win.connect("button-press-event", lambda w, ev: self._on_bar_button_press(w, ev))
        win.connect("key-press-event", self._on_window_key)
        win.connect("size-allocate", self._on_window_size_allocate)
        win.show_all()

        self._windows[monitor] = {
            "window": win,
            "list_box": list_box,
            "bottom_box": bottom_box,
            "exclusive_width": self.bar_width,
        }

    def _on_window_size_allocate(self, win, allocation):
        if allocation.width <= 0:
            return
        for win_info in self._windows.values():
            if win_info["window"] is win:
                if win_info["exclusive_width"] != allocation.width:
                    win_info["exclusive_width"] = allocation.width
                    GtkLayerShell.set_exclusive_zone(win, allocation.width)
                break

    def _on_window_key(self, widget, event):
        if event.keyval == Gdk.KEY_Escape and self.armed_key is not None:
            self.disarm_close()
            return True
        return False

    def _icon_cache_key(self, icon_spec):
        if isinstance(icon_spec, Gio.ThemedIcon):
            return ("themed", tuple(icon_spec.get_names()))
        if isinstance(icon_spec, Gio.FileIcon):
            return ("file", icon_spec.get_file().get_path())
        if isinstance(icon_spec, (list, tuple)):
            return ("list", tuple(icon_spec))
        return ("str", str(icon_spec))

    def _resolve_pixbuf(self, icon_spec, scale, symbolic_fallback=False, fg_rgba=None):
        fg_key = fg_rgba.to_string() if fg_rgba is not None else ""
        cache_key = (self._icon_cache_key(icon_spec), scale, symbolic_fallback, fg_key)
        if cache_key in self._pixbuf_cache:
            return self._pixbuf_cache[cache_key]

        pixbuf = None
        flags = Gtk.IconLookupFlags.FORCE_SIZE
        if isinstance(icon_spec, Gio.FileIcon):
            path = icon_spec.get_file().get_path()
            if path:
                try:
                    pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                        path, self.icon_size * scale, self.icon_size * scale, True
                    )
                except GLib.Error:
                    pixbuf = None
        else:
            names = []
            if isinstance(icon_spec, Gio.ThemedIcon):
                names.extend(icon_spec.get_names())
            elif isinstance(icon_spec, (list, tuple)):
                names.extend(str(item) for item in icon_spec if item)
            elif isinstance(icon_spec, str) and icon_spec:
                if os.path.isabs(icon_spec) and os.path.isfile(icon_spec):
                    try:
                        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                            icon_spec, self.icon_size * scale, self.icon_size * scale, True
                        )
                    except GLib.Error:
                        pixbuf = None
                else:
                    names.extend([icon_spec, icon_spec.lower()])
            if pixbuf is None:
                info = None
                if names:
                    # Try non-symbolic names before symbolic/fallback so theme fallbacks don't shadow hicolor app icons.
                    non_sym = [n for n in names if not n.endswith("-symbolic")]
                    if not symbolic_fallback and non_sym:
                        info = self.icon_theme.choose_icon_for_scale(non_sym, self.icon_size, scale, flags)
                    if info is None:
                        info = self.icon_theme.choose_icon_for_scale(names, self.icon_size, scale, flags)
                if info is None:
                    info = self.icon_theme.choose_icon_for_scale(
                        ["application-x-executable"], self.icon_size, scale, flags
                    )
                if info is not None:
                    try:
                        if symbolic_fallback or info.is_symbolic():
                            if fg_rgba is None:
                                probe = Gtk.Label()
                                fg_rgba = probe.get_style_context().get_color(Gtk.StateFlags.NORMAL)
                            pixbuf, _ = info.load_symbolic(fg_rgba, fg_rgba, fg_rgba, fg_rgba)
                        else:
                            pixbuf = info.load_icon()
                    except GLib.Error:
                        pixbuf = None

        self._pixbuf_cache[cache_key] = pixbuf
        return pixbuf

    def _make_button(self, slot, pinned_count, scale, show_title=False):
        btn = Gtk.Button()
        btn.set_relief(Gtk.ReliefStyle.NONE)
        btn.set_can_focus(False)
        ctx = btn.get_style_context()
        ctx.add_class("appbar-item")
        if slot.pinned:
            ctx.add_class("is-pinned")
        if slot.is_system:
            ctx.add_class("is-system")
        if slot.active:
            ctx.add_class("is-active")
        elif slot.windows:
            ctx.add_class("is-running")
        armed = self.armed_key is not None and self.armed_key == slot.key
        if armed:
            ctx.add_class("is-armed")

        overlay = Gtk.Overlay()
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        content.set_valign(Gtk.Align.CENTER)
        image = Gtk.Image()
        image.set_halign(Gtk.Align.CENTER)
        image.set_valign(Gtk.Align.CENTER)
        image.set_margin_start(6)
        image.set_margin_end(6)
        fg_rgba = ctx.get_color(Gtk.StateFlags.NORMAL) if slot.is_system else None
        pixbuf = self._resolve_pixbuf(slot.icon_spec, scale, symbolic_fallback=slot.is_system, fg_rgba=fg_rgba)
        if pixbuf is not None:
            surface = Gdk.cairo_surface_create_from_pixbuf(pixbuf, scale, None)
            image.set_from_surface(surface)
        else:
            image.set_from_icon_name("application-x-executable", Gtk.IconSize.LARGE_TOOLBAR)
        content.pack_start(image, False, False, 0)

        if show_title and not slot.is_system and bool(slot.windows):
            title_lbl = Gtk.Label(label=format_app_title(slot.name))
            title_lbl.set_angle(270)
            title_lbl.set_single_line_mode(True)
            title_lbl.set_halign(Gtk.Align.CENTER)
            title_lbl.get_style_context().add_class("appbar-title")
            content.pack_start(title_lbl, False, False, 0)

        overlay.add(content)

        dot_count = 1 if slot.active else min(len(slot.windows), 3)
        if dot_count > 0:
            dots = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            dots.set_halign(Gtk.Align.START)
            dots.set_valign(Gtk.Align.CENTER)
            dots.set_margin_start(1)
            dots.get_style_context().add_class("appbar-dots")
            for _ in range(dot_count):
                dot = Gtk.Box()
                dot.get_style_context().add_class("appbar-dot")
                if slot.active:
                    dot.get_style_context().add_class("is-active")
                if armed:
                    dot.get_style_context().add_class("is-armed")
                dots.pack_start(dot, False, False, 0)
            overlay.add_overlay(dots)
            overlay.set_overlay_pass_through(dots, True)

        btn.add(overlay)

        if armed:
            btn.set_tooltip_text(f"Middle-click again to close {slot.name}")
        elif len(slot.windows) == 1 and slot.windows[0].title:
            btn.set_tooltip_text(f"{slot.name} — {slot.windows[0].title}")
        elif len(slot.windows) > 1:
            btn.set_tooltip_text(f"{slot.name} ({len(slot.windows)} windows)")
        else:
            btn.set_tooltip_text(slot.name)

        btn.connect("clicked", lambda _w, s=slot: self._on_left_click(s))
        btn.connect("button-press-event", lambda w, ev, s=slot, pc=pinned_count: self._on_button_press(w, ev, s, pc))

        if not slot.is_system:
            desktop_file = resolve_slot_desktop_file(slot)
            if desktop_file:
                btn.drag_source_set(Gdk.ModifierType.BUTTON1_MASK, [], Gdk.DragAction.COPY)
                btn.drag_source_add_uri_targets()
                if pixbuf is not None:
                    btn.connect("drag-begin", lambda _w, ctx, pb=pixbuf: Gtk.drag_set_icon_pixbuf(ctx, pb, 0, 0))
                btn.connect(
                    "drag-data-get",
                    lambda _w, _ctx, data, _info, _t, df=desktop_file: data.set_uris([Path(df).as_uri()]),
                )

            btn.drag_dest_set(Gtk.DestDefaults.DROP, [], Gdk.DragAction.COPY | Gdk.DragAction.MOVE)
            btn.drag_dest_add_uri_targets()
            btn.connect("drag-motion", self._on_slot_drag_motion)
            btn.connect("drag-leave", self._on_slot_drag_leave)
            btn.connect(
                "drag-data-received",
                lambda w, ctx, x, y, data, info, time, s=slot: self._on_slot_drag_data_received(
                    w, ctx, x, y, data, info, time, s
                ),
            )
        else:
            btn.drag_dest_set(Gtk.DestDefaults.DROP, [], Gdk.DragAction.COPY | Gdk.DragAction.MOVE)
            btn.drag_dest_add_uri_targets()
            btn.connect("drag-motion", self._on_slot_drag_motion)
            btn.connect("drag-leave", self._on_slot_drag_leave)
            btn.connect(
                "drag-data-received",
                lambda w, ctx, x, y, data, info, time: self._on_system_drag_data_received(
                    w, ctx, x, y, data, info, time
                ),
            )

        return btn

    def rebuild_ui(self):
        toplevels = self.wlr.list_toplevels()
        pinned_slots, unpinned_slots, menu_slot = merge_apps(self.pins, toplevels, self.catalog)

        # Keep last focused handle per app and clear stale close arming if app vanished.
        live_keys = set()
        for slot in (*pinned_slots, *unpinned_slots):
            if slot.windows:
                live_keys.add(slot.key)
                active_win = next((w for w in slot.windows if w.activated), None)
                if active_win is not None:
                    self.focused_handles[slot.key] = active_win.handle_id
                elif self.focused_handles.get(slot.key) not in {w.handle_id for w in slot.windows}:
                    self.focused_handles.pop(slot.key, None)
        if self.armed_key is not None and self.armed_key not in live_keys:
            self.disarm_close(rebuild=False)

        pinned_count = len(pinned_slots)
        show_titles = should_show_titles(pinned_slots, unpinned_slots)
        for win_info in self._windows.values():
            scale = win_info["window"].get_scale_factor() or 1
            list_box = win_info["list_box"]
            bottom_box = win_info["bottom_box"]

            for child in list_box.get_children():
                list_box.remove(child)
            for child in bottom_box.get_children():
                bottom_box.remove(child)

            for slot in pinned_slots:
                list_box.pack_start(self._make_button(slot, pinned_count, scale, show_title=show_titles), False, False, 0)

            if pinned_slots and unpinned_slots:
                sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
                sep.get_style_context().add_class("appbar-sep")
                list_box.pack_start(sep, False, False, 0)

            for slot in unpinned_slots:
                list_box.pack_start(self._make_button(slot, pinned_count, scale, show_title=show_titles), False, False, 0)

            sep_bottom = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
            sep_bottom.get_style_context().add_class("appbar-sep")
            bottom_box.pack_start(sep_bottom, False, False, 0)
            bottom_box.pack_start(self._make_button(menu_slot, pinned_count, scale, show_title=False), False, False, 0)

            list_box.show_all()
            bottom_box.show_all()

    def _launch_slot(self, slot):
        if slot.is_system:
            cmd = slot.command or "$HOME/.local/bin/hakumenu.sh"
            self._spawn_shell(cmd)
            return
        if slot.desktop_info is not None:
            try:
                slot.desktop_info.launch([], None)
                return
            except GLib.Error as err:
                print(f"[appbar-layer] Failed launching {slot.desktop_id}: {err}", file=sys.stderr)
        if slot.command:
            self._spawn_shell(slot.command)
        elif slot.app_id:
            self._spawn_shell(slot.app_id)

    def _spawn_shell(self, command):
        try:
            GLib.spawn_async(
                ["sh", "-c", command],
                flags=GLib.SpawnFlags.SEARCH_PATH,
            )
        except GLib.Error as err:
            print(f"[appbar-layer] Spawn error '{command}': {err}", file=sys.stderr)

    def _on_left_click(self, slot):
        self.disarm_close()
        if slot.is_system or not slot.windows:
            self._launch_slot(slot)
            return
        win = next_window_to_activate(slot.windows, self.focused_handles.get(slot.key))
        if win is not None:
            self.focused_handles[slot.key] = win.handle_id
            self.wlr.activate(win.handle_id)

    def _on_list_drag_motion(self, widget, context, _x, _y, time):
        widget.get_style_context().add_class("is-drop-pin")
        Gdk.drag_status(context, Gdk.DragAction.COPY, time)
        return True

    def _on_list_drag_leave(self, widget, _context, _time):
        widget.get_style_context().remove_class("is-drop-pin")

    def _on_slot_drag_motion(self, widget, context, _x, _y, time):
        widget.get_style_context().add_class("is-drop-target")
        Gdk.drag_status(context, Gdk.DragAction.COPY, time)
        return True

    def _on_slot_drag_leave(self, widget, _context, _time):
        widget.get_style_context().remove_class("is-drop-target")

    def _compute_drop_pin_index(self, list_box, y):
        pinned_children = [
            w for w in list_box.get_children()
            if isinstance(w, Gtk.Button) and w.get_style_context().has_class("is-pinned")
        ]
        for idx, btn in enumerate(pinned_children):
            alloc = btn.get_allocation()
            if y < alloc.y + (alloc.height / 2.0):
                return idx
        return len(pinned_children)

    def _on_list_drag_data_received(self, widget, context, _x, y, data, _info, time):
        widget.get_style_context().remove_class("is-drop-pin")
        paths = parse_drop_uris(data.get_uris() if data is not None else ())
        pin_ids, _other = classify_pin_drop_ids(paths)
        if pin_ids:
            target_idx = self._compute_drop_pin_index(widget, y)
            self._pin_dropped_apps(pin_ids, target_app_idx=target_idx)
            Gtk.drag_finish(context, True, False, time)
            return
        Gtk.drag_finish(context, False, False, time)

    def _on_system_drag_data_received(self, widget, context, _x, _y, data, _info, time):
        widget.get_style_context().remove_class("is-drop-target")
        paths = parse_drop_uris(data.get_uris() if data is not None else ())
        pin_ids, _other = classify_pin_drop_ids(paths)
        if pin_ids:
            self._pin_dropped_apps(pin_ids)
            Gtk.drag_finish(context, True, False, time)
            return
        Gtk.drag_finish(context, False, False, time)

    def _on_slot_drag_data_received(self, widget, context, _x, _y, data, _info, time, slot):
        widget.get_style_context().remove_class("is-drop-target")
        paths = parse_drop_uris(data.get_uris() if data is not None else ())
        if not paths:
            Gtk.drag_finish(context, False, False, time)
            return

        pin_ids, other_paths = classify_pin_drop_ids(paths)
        shift_held = False
        try:
            display = widget.get_display()
            seat = display.get_default_seat() if display is not None else None
            pointer = seat.get_pointer() if seat is not None else None
            if pointer is not None:
                _scr, _px, _py, mask = pointer.get_state()
                shift_held = bool(mask & Gdk.ModifierType.SHIFT_MASK)
        except Exception:
            pass

        if pin_ids and not other_paths and (slot.pinned or shift_held or slot.desktop_info is None):
            target_idx = slot.pin_index if slot.pinned and slot.pin_index >= 0 else None
            self._pin_dropped_apps(pin_ids, target_app_idx=target_idx)
            Gtk.drag_finish(context, True, False, time)
            return

        ok = self._open_paths_with_slot(slot, paths)
        Gtk.drag_finish(context, ok, False, time)

    def _open_paths_with_slot(self, slot, paths):
        files = [Gio.File.new_for_path(p) for p in paths]
        if slot.desktop_info is not None:
            try:
                slot.desktop_info.launch(files, None)
                return True
            except GLib.Error as err:
                print(f"[appbar-layer] Failed launching {slot.desktop_id} with files: {err}", file=sys.stderr)
        if slot.command:
            quoted = " ".join(shlex.quote(p) for p in paths)
            self._spawn_shell(f"{slot.command} {quoted}")
            return True
        if slot.app_id:
            try:
                GLib.spawn_async([slot.app_id, *paths], flags=GLib.SpawnFlags.SEARCH_PATH)
                return True
            except GLib.Error as err:
                print(f"[appbar-layer] Failed spawning {slot.app_id}: {err}", file=sys.stderr)
        return False

    def _run_pin_cmd_with_cb(self, args, on_done=None):
        try:
            proc = Gio.Subprocess.new(
                [sys.executable, self.pinned_ctl, *args],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
            )
        except GLib.Error as err:
            print(f"[appbar-layer] Pin command failed: {err}", file=sys.stderr)
            if on_done is not None:
                on_done(False)
            return

        def _done(p, result):
            ok = False
            try:
                _, stdout, stderr = p.communicate_utf8_finish(result)
                if p.get_successful() and stdout:
                    parsed = json.loads(stdout)
                    if isinstance(parsed, list):
                        self.pins = parsed
                        self.rebuild_ui()
                        ok = True
                elif stderr:
                    print(f"[appbar-layer] {stderr.strip()}", file=sys.stderr)
            except (GLib.Error, ValueError) as err:
                print(f"[appbar-layer] Pin parse error: {err}", file=sys.stderr)
            if on_done is not None:
                on_done(ok)

        proc.communicate_utf8_async(None, None, _done)

    def _pin_dropped_apps(self, pin_ids, target_app_idx=None):
        queue = list(pin_ids)
        if not queue:
            return

        def _step(idx_offset=0):
            if not queue:
                return
            pid = queue.pop(0)
            def _after_add(ok):
                if ok and target_app_idx is not None:
                    app_positions = [
                        i for i, pin in enumerate(self.pins)
                        if pin.get("type") != "system" and pin.get("id") != "menu"
                    ]
                    src_raw = next(
                        (i for i, pin in enumerate(self.pins) if normalize_id(pin.get("id", "")) == normalize_id(pid)),
                        None,
                    )
                    if src_raw is not None and app_positions:
                        dest_app = min(max(0, target_app_idx + idx_offset), len(app_positions) - 1)
                        dest_raw = app_positions[dest_app]
                        if src_raw != dest_raw:
                            self._run_pin_cmd_with_cb(
                                ["move", str(src_raw), str(dest_raw)],
                                on_done=lambda _m: _step(idx_offset + 1),
                            )
                            return
                _step(idx_offset + 1)

            self._run_pin_cmd_with_cb(["add", pid], on_done=_after_add)

        _step(0)

    def toggle_show_desktop(self):
        toplevels = self.wlr.list_toplevels()
        minimize_now, targets = compute_show_desktop_plan(toplevels, self._show_desktop_handles)
        if not targets:
            self._show_desktop_handles.clear()
            return False
        for hid in targets:
            self.wlr.set_minimized(hid, minimize_now)
        if minimize_now:
            self._show_desktop_handles = set(targets)
        else:
            self._show_desktop_handles.clear()
        return True

    def _append_desktop_actions(self, menu):
        minimize_now, targets = compute_show_desktop_plan(
            self.wlr.list_toplevels(), self._show_desktop_handles
        )
        sd_label = "Show Desktop" if minimize_now or not targets else "Restore Windows"
        sd_item = Gtk.MenuItem(label=sd_label)
        sd_item.set_sensitive(bool(targets))
        sd_item.connect("activate", lambda _w: self.toggle_show_desktop())
        menu.append(sd_item)

        icons_ctl = resolve_desktop_icons_ctl()
        if icons_ctl:
            di_item = Gtk.CheckMenuItem(label="Desktop Icons")
            di_item.set_active(query_desktop_icons_enabled())
            di_item.connect(
                "toggled",
                lambda _w, cmd=icons_ctl: subprocess.Popen([cmd, "--toggle"]),
            )
            menu.append(di_item)

    def _on_bar_button_press(self, win, event):
        if event.button == 3:
            self.disarm_close()
            self._show_bar_context_menu(win, event)
            return True
        return False

    def _show_bar_context_menu(self, anchor_widget, event):
        menu = Gtk.Menu()
        header = Gtk.MenuItem(label="AppBar")
        header.set_sensitive(False)
        menu.append(header)
        menu.append(Gtk.SeparatorMenuItem())

        open_menu_item = Gtk.MenuItem(label="Open Applications Menu")
        open_menu_item.connect("activate", lambda _w: self._spawn_shell("$HOME/.local/bin/hakumenu.sh"))
        menu.append(open_menu_item)
        menu.append(Gtk.SeparatorMenuItem())

        self._append_desktop_actions(menu)
        menu.show_all()
        menu.popup_at_pointer(event)

    def _on_button_press(self, widget, event, slot, pinned_count):
        if event.button == 2:
            self._on_middle_click(slot)
            return True
        if event.button == 3:
            self.disarm_close()
            self._show_context_menu(widget, event, slot, pinned_count)
            return True
        return False

    def _on_middle_click(self, slot):
        if slot.is_system or not slot.windows:
            self.disarm_close()
            return
        if self.armed_key == slot.key:
            self.disarm_close(rebuild=False)
            for win in slot.windows:
                self.wlr.close(win.handle_id)
            self.rebuild_ui()
            return
        self.arm_close(slot.key)

    def arm_close(self, key):
        if self._arm_timer_id:
            GLib.source_remove(self._arm_timer_id)
        self.armed_key = key
        self._arm_timer_id = GLib.timeout_add(ARM_TIMEOUT_MS, self._on_arm_timeout)
        self.rebuild_ui()

    def _on_arm_timeout(self):
        self._arm_timer_id = 0
        self.armed_key = None
        self.rebuild_ui()
        return GLib.SOURCE_REMOVE

    def disarm_close(self, rebuild=True):
        changed = self.armed_key is not None
        if self._arm_timer_id:
            GLib.source_remove(self._arm_timer_id)
            self._arm_timer_id = 0
        self.armed_key = None
        if rebuild and changed:
            self.rebuild_ui()

    def _show_context_menu(self, widget, event, slot, pinned_count):
        menu = Gtk.Menu()
        info_text = slot.name
        if not slot.is_system:
            ident = slot.app_id or slot.pin_id
            win_label = f"{len(slot.windows)} open" if slot.windows else "not running"
            info_text = f"{slot.name} ({ident}) · {win_label}"
        header = Gtk.MenuItem(label=info_text)
        header.set_sensitive(False)
        menu.append(header)
        menu.append(Gtk.SeparatorMenuItem())

        if slot.is_system:
            open_item = Gtk.MenuItem(label="Open Menu")
            open_item.connect("activate", lambda _w: self._launch_slot(slot))
            menu.append(open_item)
            menu.append(Gtk.SeparatorMenuItem())
            self._append_desktop_actions(menu)
        else:
            for win in slot.windows:
                title = (win.title or slot.name).strip()
                if len(title) > 42:
                    title = title[:39] + "..."
                prefix = "▶ " if win.activated else "   "
                win_item = Gtk.MenuItem(label=f"{prefix}{title}")
                win_item.connect("activate", lambda _w, hid=win.handle_id: self.wlr.activate(hid))
                menu.append(win_item)

            if slot.windows:
                menu.append(Gtk.SeparatorMenuItem())

            if slot.desktop_info is not None or slot.command:
                launch_label = "New Window" if slot.windows else "Launch"
                launch_item = Gtk.MenuItem(label=launch_label)
                launch_item.connect("activate", lambda _w: self._launch_slot(slot))
                menu.append(launch_item)

            if slot.pinned:
                unpin_item = Gtk.MenuItem(label="Unpin from AppBar")
                unpin_item.connect("activate", lambda _w: self._run_pin_cmd(["remove", slot.pin_id]))
                menu.append(unpin_item)
                if slot.pin_index > 0:
                    up_item = Gtk.MenuItem(label="Move Up")
                    up_item.connect("activate", lambda _w: self._move_pin(slot.pin_index, slot.pin_index - 1))
                    menu.append(up_item)
                if 0 <= slot.pin_index < pinned_count - 1:
                    down_item = Gtk.MenuItem(label="Move Down")
                    down_item.connect("activate", lambda _w: self._move_pin(slot.pin_index, slot.pin_index + 1))
                    menu.append(down_item)
            else:
                pin_target = slot.desktop_id.removesuffix(".desktop") if slot.desktop_id else slot.app_id
                if pin_target:
                    pin_item = Gtk.MenuItem(label="Pin to AppBar")
                    pin_item.connect("activate", lambda _w, pid=pin_target: self._run_pin_cmd(["add", pid]))
                    menu.append(pin_item)

            if slot.windows:
                menu.append(Gtk.SeparatorMenuItem())
                close_label = "Close All Windows" if len(slot.windows) > 1 else "Close Window"
                close_item = Gtk.MenuItem(label=close_label)
                close_item.connect(
                    "activate",
                    lambda _w, wins=list(slot.windows): [self.wlr.close(w.handle_id) for w in wins],
                )
                menu.append(close_item)

        menu.show_all()
        menu.popup_at_widget(widget, Gdk.Gravity.EAST, Gdk.Gravity.WEST, event)

    def _move_pin(self, app_idx, target_app_idx):
        # pinned_apps_ctl.py indices include system entries such as image#menu.
        app_positions = [i for i, pin in enumerate(self.pins) if pin.get("type") != "system" and pin.get("id") != "menu"]
        if 0 <= app_idx < len(app_positions) and 0 <= target_app_idx < len(app_positions):
            self._run_pin_cmd(["move", str(app_positions[app_idx]), str(app_positions[target_app_idx])])

    def cleanup(self):
        if self._arm_timer_id:
            GLib.source_remove(self._arm_timer_id)
            self._arm_timer_id = 0
        if self._pin_reload_timer:
            GLib.source_remove(self._pin_reload_timer)
            self._pin_reload_timer = 0
        for win_info in self._windows.values():
            win_info["window"].destroy()
        self._windows.clear()
        self.wlr.close_client()
        if Gtk.main_level() > 0:
            Gtk.main_quit()


def parse_args():
    parser = argparse.ArgumentParser(description="Classic mode vertical left AppBar (GTK3 LayerShell).")
    parser.add_argument("--width", type=int, default=BAR_WIDTH, help=f"Bar width in pixels (default: {BAR_WIDTH})")
    parser.add_argument("--icon-size", type=int, default=ICON_SIZE, help=f"Icon size in pixels (default: {ICON_SIZE})")
    return parser.parse_args()


def add_unix_signal(sig, callback):
    """Register a GLib mainloop signal handler without deprecation warnings."""
    if GLibUnix is not None and hasattr(GLibUnix, "signal_add"):
        return GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, sig, callback)
    return GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, callback)


def main():
    args = parse_args()
    app = AppBarController(bar_width=args.width, icon_size=args.icon_size)

    def on_exit_signal(*_args):
        app.cleanup()
        return GLib.SOURCE_REMOVE

    def on_reload_signal(*_args):
        app.reload_css()
        return GLib.SOURCE_CONTINUE

    add_unix_signal(signal.SIGINT, on_exit_signal)
    add_unix_signal(signal.SIGTERM, on_exit_signal)
    add_unix_signal(signal.SIGUSR1, on_reload_signal)

    print("[appbar-layer] AppBar configured", flush=True)
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
