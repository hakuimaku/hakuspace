#!/usr/bin/env python3
import json
import math
import shutil
import subprocess
from pathlib import Path

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, Gio, GLib, GtkLayerShell, Pango

# Configuration constants
PADDING_X = 20
PADDING_Y = 18
ICON_SIZE = 60
LABEL_H = 30
DRAG_HOLD_MS = 120
DRAG_THRESHOLD = 7
FS_DEBOUNCE_MS = 140

CELL_W_MIN, CELL_W_MAX = 90, 150
CELL_H_MIN, CELL_H_MAX = 100, 170

TOP_SAFE_PX = 6
BOTTOM_SAFE_PX = 24
LEFT_SAFE_PX = 6
RIGHT_SAFE_PX = 6

LAYOUT_FILE = Path.home() / ".config" / "desktop-icons-layout.json"
THUNAR_BIN = shutil.which("thunar") or "thunar"

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def run_quiet(cmd):
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def get_desktop_dir() -> Path:
    cfg = Path.home() / ".config/user-dirs.dirs"
    if cfg.exists():
        for line in cfg.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("XDG_DESKTOP_DIR="):
                v = line.split("=", 1)[1].strip().strip('"').replace("$HOME", str(Path.home()))
                return Path(v)
    return Path.home() / "Desktop"

def list_items(desktop: Path):
    desktop.mkdir(parents=True, exist_ok=True)
    return [p for p in sorted(desktop.iterdir(), key=lambda x: x.name.lower()) if not p.name.startswith(".")]

class DesktopItem(Gtk.EventBox):
    def __init__(self, app, path: Path):
        super().__init__()
        self.app = app
        self.path = path
        self.set_visible_window(False)

        self.pointer_down = False
        self.dragging = False
        self.hold_ready = False
        self.hold_timer_id = 0
        self.press_root_x = 0.0
        self.press_root_y = 0.0
        self.drag_off_x = 0
        self.drag_off_y = 0

        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.box.get_style_context().add_class("icon-item")

        self.img = Gtk.Image.new_from_gicon(self.app.icon_for(path), Gtk.IconSize.DIALOG)
        self.img.set_pixel_size(ICON_SIZE)

        self.lbl = Gtk.Label(label=path.name)
        self.lbl.get_style_context().add_class("icon-label")
        self.lbl.set_justify(Gtk.Justification.CENTER)
        self.lbl.set_line_wrap(True)
        self.lbl.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
        self.lbl.set_ellipsize(Pango.EllipsizeMode.END)
        self.lbl.set_lines(2)
        self.lbl.set_max_width_chars(16)
        self.lbl.set_size_request(10, LABEL_H)

        self.box.pack_start(self.img, False, False, 0)
        self.box.pack_start(self.lbl, False, False, 0)
        self.add(self.box)

        self.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK
            | Gdk.EventMask.BUTTON_RELEASE_MASK
            | Gdk.EventMask.POINTER_MOTION_MASK
            | Gdk.EventMask.ENTER_NOTIFY_MASK
            | Gdk.EventMask.LEAVE_NOTIFY_MASK
        )
        self.connect("button-press-event", self.on_button_press)
        self.connect("button-release-event", self.on_button_release)
        self.connect("motion-notify-event", self.on_motion)
        self.connect("enter-notify-event", self.on_enter)
        self.connect("leave-notify-event", self.on_leave)

        self.restyle_size()

    def restyle_size(self):
        self.box.set_size_request(self.app.cell_w, self.app.cell_h)
        self.lbl.set_size_request(self.app.cell_w - 6, LABEL_H)

    def set_selected(self, selected):
        ctx = self.box.get_style_context()
        if selected: ctx.add_class("selected")
        else: ctx.remove_class("selected")

    def on_enter(self, *_):
        self.box.get_style_context().add_class("hover")
        return False

    def on_leave(self, *_):
        self.box.get_style_context().remove_class("hover")
        return False

    def _hold_ready_cb(self):
        self.hold_ready = True
        self.hold_timer_id = 0
        return False

    def on_button_press(self, _, event):
        if event.button == 3 and event.type == Gdk.EventType.BUTTON_PRESS:
            self.app.select_item(self)
            self.app.show_item_menu(self, event)
            return True

        if event.button != 1:
            return False

        if event.type == Gdk.EventType._2BUTTON_PRESS:
            self.app.select_item(self)
            self.app.open_path(self.path)
            return True

        if event.type == Gdk.EventType.BUTTON_PRESS:
            self.app.select_item(self)
            self.pointer_down = True
            self.dragging = False
            self.hold_ready = False
            self.press_root_x = event.x_root
            self.press_root_y = event.y_root
            self.drag_off_x = int(event.x)
            self.drag_off_y = int(event.y)
            if self.hold_timer_id:
                GLib.source_remove(self.hold_timer_id)
            self.hold_timer_id = GLib.timeout_add(DRAG_HOLD_MS, self._hold_ready_cb)
            return True
        return False

    def on_motion(self, _, event):
        if not self.pointer_down:
            return False
        dx = event.x_root - self.press_root_x
        dy = event.y_root - self.press_root_y
        if not self.dragging:
            if self.hold_ready and math.hypot(dx, dy) >= DRAG_THRESHOLD:
                self.dragging = True
                self.app.begin_fullscreen_drag()
            else:
                return False
        nx = int(event.x_root - self.app.win_x - self.drag_off_x)
        ny = int(event.y_root - self.app.win_y - self.drag_off_y)
        self.app.layout.move(self, nx, ny)
        return True

    def on_button_release(self, _, event):
        if event.button != 1:
            return False
        if self.hold_timer_id:
            GLib.source_remove(self.hold_timer_id)
            self.hold_timer_id = 0

        was_dragging = self.dragging
        self.pointer_down = False
        self.dragging = False
        self.hold_ready = False

        if was_dragging:
            x = self.app.layout.child_get_property(self, "x")
            y = self.app.layout.child_get_property(self, "y")
            col = round((x - PADDING_X) / self.app.cell_w)
            row = round((y - PADDING_Y) / self.app.cell_h)
            row, col = self.app.clamp_cell(row, col)
            self.app.place_item_in_cell(self, row, col, True)
            self.app.save_layout()
            self.app.end_fullscreen_drag()

        if self.app.pending_refresh:
            self.app.pending_refresh = False
            self.app.schedule_refresh()
        return True

class DesktopLayer(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_decorated(False)
        self.set_app_paintable(True)
        self.set_accept_focus(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.stick()

        self.desktop = get_desktop_dir()
        self.icon_cache = {}
        self.refresh_scheduled = 0

        self.full_drag_mode = False

        screen = self.get_screen()
        rgba = screen.get_rgba_visual()
        if rgba and screen.is_composited():
            self.set_visual(rgba)

        css = b"""
        window { background-color: rgba(0,0,0,0); }
        .icon-item { padding: 4px; background-color: rgba(0,0,0,0); }
        .icon-item.hover { background-color: rgba(255,255,255,0.07); }
        .icon-item.selected { background-color: rgba(255,255,255,0.12); }
        .icon-label { color: #eaeaea; }
        """
        prov = Gtk.CssProvider()
        prov.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(screen, prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BOTTOM)
        for edge in [GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.LEFT]:
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, False)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, False)
        GtkLayerShell.set_exclusive_zone(self, 0)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        self.layout = Gtk.Fixed()
        self.add(self.layout)

        self.items = {}
        self.cell_map = {}
        self.positions = self.load_layout()
        self.selected_name = None

        self.win_x, self.win_y = 0, 0
        self.cell_w = 110
        self.cell_h = 120
        self.grid_cols = 8
        self.max_rows = 6
        self.mon_w = 1920
        self.mon_h = 1080

        self.is_dragging_any = False
        self.pending_refresh = False

        self.connect("destroy", Gtk.main_quit)
        self.connect("realize", self.on_realize)
        self.connect("size-allocate", self.on_size_allocate)
        self.connect("key-press-event", self.on_key_press)

        self.monitor = Gio.File.new_for_path(str(self.desktop)).monitor_directory(Gio.FileMonitorFlags.NONE, None)
        self.monitor.connect("changed", self.on_fs_changed)

        self.recompute_grid()
        self.refresh()

    def open_path(self, path: Path):
        if path.is_dir():
            run_quiet([THUNAR_BIN, str(path)])
        else:
            run_quiet(["xdg-open", str(path)])

    def open_in_thunar(self, path: Path):
        target = path if path.is_dir() else path.parent
        run_quiet([THUNAR_BIN, str(target)])

    def move_to_trash(self, path: Path):
        try:
            gfile = Gio.File.new_for_path(str(path))
            gfile.trash(None)
        except Exception as e:
            print(f"Error moving to trash: {e}")

    def icon_for(self, path: Path):
        key = "dir" if path.is_dir() else (path.suffix.lower() or "file")
        ico = self.icon_cache.get(key)
        if ico:
            return ico
        if path.is_dir():
            ico = Gio.ThemedIcon.new("folder")
        else:
            ico = Gio.ThemedIcon.new("text-x-generic")
        self.icon_cache[key] = ico
        return ico

    def clamp_cell(self, row, col):
        return clamp(int(row), 0, self.max_rows - 1), clamp(int(col), 0, self.grid_cols - 1)

    def recompute_grid(self):
        d = Gdk.Display.get_default()
        mon = d.get_primary_monitor() or d.get_monitor(0)
        geo = mon.get_geometry()
        self.mon_w, self.mon_h = max(1, geo.width), max(1, geo.height)

        self.cell_w = clamp(int(self.mon_w * 0.07), CELL_W_MIN, CELL_W_MAX)
        self.cell_h = clamp(int(self.mon_h * 0.11), CELL_H_MIN, CELL_H_MAX)

        usable_w = max(1, self.mon_w - PADDING_X - LEFT_SAFE_PX - RIGHT_SAFE_PX)
        usable_h = max(1, self.mon_h - PADDING_Y - TOP_SAFE_PX - BOTTOM_SAFE_PX)
        self.grid_cols = max(1, usable_w // self.cell_w)
        self.max_rows = max(1, usable_h // self.cell_h)
        if self.mon_h <= 900:
            self.max_rows = min(self.max_rows, 6)

    def on_realize(self, *_):
        gw = self.get_window()
        if gw:
            self.win_x, self.win_y = gw.get_root_origin()
        self.recompute_grid()
        self.refresh()

    def on_size_allocate(self, *_):
        old = (self.cell_w, self.cell_h, self.grid_cols, self.max_rows)
        self.recompute_grid()
        new = (self.cell_w, self.cell_h, self.grid_cols, self.max_rows)
        if old != new and not self.full_drag_mode:
            self.schedule_refresh()

    def on_key_press(self, _, event):
        if event.keyval == Gdk.KEY_F2:
            self.rename_selected(); return True
        if event.keyval == Gdk.KEY_Escape:
            self.clear_selection(); return True
        if event.keyval == Gdk.KEY_Delete:
            if self.selected_name and self.selected_name in self.items:
                self.move_to_trash(self.items[self.selected_name].path)
            return True
        return False

    def on_fs_changed(self, *_):
        if self.full_drag_mode:
            self.pending_refresh = True
            return
        self.schedule_refresh()

    def schedule_refresh(self):
        if self.refresh_scheduled:
            return
        self.refresh_scheduled = GLib.timeout_add(FS_DEBOUNCE_MS, self._do_scheduled_refresh)

    def _do_scheduled_refresh(self):
        self.refresh_scheduled = 0
        self.refresh()
        return False

    def begin_fullscreen_drag(self):
        if self.full_drag_mode:
            return
        self.full_drag_mode = True
        self.is_dragging_any = True

        # expand to full monitor
        self.move(0, 0)
        self.resize(self.mon_w, self.mon_h)

    def end_fullscreen_drag(self):
        self.full_drag_mode = False
        self.is_dragging_any = False
        self.fit_window_to_items()

    def clear_selection(self):
        self.selected_name = None
        for it in self.items.values():
            it.set_selected(False)

    def select_item(self, item):
        if self.selected_name == item.path.name:
            self.selected_name = None
        else:
            self.selected_name = item.path.name

        for n, it in self.items.items():
            it.set_selected(n == self.selected_name)

    def rename_selected(self):
        if not self.selected_name or self.selected_name not in self.items:
            return
        old_path = self.items[self.selected_name].path
        dlg = Gtk.Dialog(title="Rename", transient_for=self, flags=0)
        dlg.add_button("_Cancel", Gtk.ResponseType.CANCEL)
        dlg.add_button("_OK", Gtk.ResponseType.OK)
        entry = Gtk.Entry()
        entry.set_text(old_path.name)
        entry.set_activates_default(True)
        area = dlg.get_content_area()
        area.pack_start(entry, True, True, 8)
        dlg.set_default_response(Gtk.ResponseType.OK)
        dlg.show_all()
        resp = dlg.run()
        new_name = entry.get_text().strip()
        dlg.destroy()
        if resp != Gtk.ResponseType.OK or not new_name or "/" in new_name or new_name == old_path.name:
            return
        new_path = old_path.parent / new_name
        if new_path.exists():
            return
        try:
            old_path.rename(new_path)
            if old_path.name in self.positions:
                self.positions[new_name] = self.positions.pop(old_path.name)
                self.write_layout(self.positions)
            self.selected_name = new_name
            self.schedule_refresh()
        except Exception:
            pass

    def show_item_menu(self, item, event):
        m = Gtk.Menu()
        def add(label, cb):
            mi = Gtk.MenuItem(label=label); mi.connect("activate", cb); m.append(mi)

        add("Open", lambda *_: self.open_path(item.path))
        add("Open in Thunar", lambda *_: self.open_in_thunar(item.path))
        add("Rename", lambda *_: self.rename_selected())
        add("Move to Trash", lambda *_: self.move_to_trash(item.path))

        m.show_all()
        m.popup_at_pointer(event)

    def load_layout(self):
        try:
            if LAYOUT_FILE.exists():
                d = json.loads(LAYOUT_FILE.read_text(encoding="utf-8"))
                return d if isinstance(d, dict) else {}
        except Exception:
            pass
        return {}

    def write_layout(self, data):
        LAYOUT_FILE.parent.mkdir(parents=True, exist_ok=True)
        LAYOUT_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")

    def sanitize_positions(self):
        changed = False
        clean = {}
        for name, pos in self.positions.items():
            if not isinstance(pos, dict):
                changed = True
                continue
            r, c = self.clamp_cell(int(pos.get("row", 0)), int(pos.get("col", 0)))
            if r != pos.get("row", 0) or c != pos.get("col", 0):
                changed = True
            clean[name] = {"row": r, "col": c}
        if changed:
            self.positions = clean
            self.write_layout(clean)

    def save_layout(self):
        d = {}
        for name, it in self.items.items():
            x = self.layout.child_get_property(it, "x")
            y = self.layout.child_get_property(it, "y")
            c = int(round((x - PADDING_X) / self.cell_w))
            r = int(round((y - PADDING_Y) / self.cell_h))
            r, c = self.clamp_cell(r, c)
            d[name] = {"row": r, "col": c}
        self.positions = d
        self.write_layout(d)

    def clear(self):
        for c in self.layout.get_children():
            self.layout.remove(c)
        self.items.clear()
        self.cell_map.clear()

    def cell_to_xy(self, r, c):
        return PADDING_X + c * self.cell_w, PADDING_Y + r * self.cell_h

    def find_next_free_cell(self, sr=0, sc=0):
        sr, sc = self.clamp_cell(sr, sc)
        for r in range(sr, self.max_rows):
            c0 = sc if r == sr else 0
            for c in range(c0, self.grid_cols):
                if (r, c) not in self.cell_map:
                    return r, c
        return self.max_rows - 1, self.grid_cols - 1

    def place_item_in_cell(self, item, r, c, resolve_collision=True):
        r, c = self.clamp_cell(r, c)
        name = item.path.name

        for k, v in list(self.cell_map.items()):
            if v == name:
                del self.cell_map[k]

        tgt = (r, c)
        if tgt in self.cell_map and self.cell_map[tgt] != name:
            other = self.cell_map[tgt]
            if resolve_collision and other in self.items:
                fr, fc = self.find_next_free_cell(0, 0)
                ox, oy = self.cell_to_xy(fr, fc)
                self.layout.move(self.items[other], ox, oy)
                self.cell_map[(fr, fc)] = other
            del self.cell_map[tgt]

        x, y = self.cell_to_xy(r, c)
        self.layout.move(item, x, y)
        self.cell_map[(r, c)] = name

    def initial_place(self, item, idx):
        name = item.path.name
        pos = self.positions.get(name)
        if isinstance(pos, dict):
            r, c = self.clamp_cell(int(pos.get("row", 0)), int(pos.get("col", 0)))
            if (r, c) not in self.cell_map:
                self.place_item_in_cell(item, r, c, False)
                return
        r = idx // self.grid_cols
        c = idx % self.grid_cols
        r, c = self.clamp_cell(r, c)
        if (r, c) in self.cell_map:
            r, c = self.find_next_free_cell(0, 0)
        self.place_item_in_cell(item, r, c, False)

    def fit_window_to_items(self):
        if self.full_drag_mode:
            return

        # compute bounding box of used cells
        if not self.cell_map:
            w = self.cell_w + PADDING_X * 2
            h = self.cell_h + PADDING_Y * 2
            self.move(0, 0)
            self.resize(w, h)
            return

        max_row = max(r for (r, _c) in self.cell_map.keys())
        max_col = max(c for (_r, c) in self.cell_map.keys())

        w = PADDING_X + (max_col + 1) * self.cell_w + 8
        h = PADDING_Y + (max_row + 1) * self.cell_h + 8

        w = min(w, self.mon_w)
        h = min(h, self.mon_h)

        self.move(0, 0)
        self.resize(w, h)

    def refresh(self):
        keep = self.selected_name
        self.recompute_grid()
        self.sanitize_positions()
        items = list_items(self.desktop)

        self.clear()
        for idx, p in enumerate(items):
            it = DesktopItem(self, p)
            self.layout.put(it, 0, 0)
            self.items[p.name] = it
            self.initial_place(it, idx)

        for it in self.items.values():
            it.restyle_size()

        if keep and keep in self.items:
            self.select_item(self.items[keep])

        self.fit_window_to_items()
        self.show_all()

if __name__ == "__main__":
    win = DesktopLayer()
    win.show_all()
    Gtk.main()