#!/usr/bin/env python3
"""Hakuspace desktop icon manager."""

import json
import os
import configparser
import shutil
import xml.etree.ElementTree as ET
import shlex
import fnmatch
import mimetypes

import gi
import sys
import cairo
import subprocess
import hashlib
import urllib.parse
from math import pi
gi.require_version('Gtk', '3.0')
try:
    gi.require_version('GtkLayerShell', '0.1')
except ValueError:
    print("Error: GtkLayerShell is not installed. Please install 'gtk-layer-shell'.")
    sys.exit(1)

try:
    gi.require_version('GioUnix', '2.0')
    from gi.repository import GioUnix
    HAS_GIO_UNIX = True
except (ValueError, ImportError):
    HAS_GIO_UNIX = False

from gi.repository import Gtk, Gdk, GtkLayerShell, Gio, GLib, GdkPixbuf


# Default Constants
ICON_SIZE = 70
CELL_WIDTH = 100
CELL_HEIGHT = 100
PADDING = 6

CONFIG_DIR = os.path.expanduser("~/hakucfg/config/desktop-icons")
POSITIONS_FILE = os.path.join(CONFIG_DIR, "positions.json")
CSS_FILE = os.path.join(CONFIG_DIR, "desktop-icons.css")
CONF_FILE = os.path.join(CONFIG_DIR, "desktop-icons.conf")

DEFAULT_CSS = """
.desktop-icon {
    background-color: rgba(0, 0, 0, 0);
    border-radius: 12px;
    border: 1px solid transparent;
    padding: 2px;
    transition: all 200ms ease-in-out;
}
.desktop-icon.hovered {
    background-color: rgba(255, 255, 255, 0.1);
    border-color: rgba(255, 255, 255, 0.15);
    box-shadow: 0 0 10px rgba(255, 255, 255, 0.1);
}
.desktop-icon.selected {
    background-color: rgba(255, 255, 255, 0.2);
    border-color: rgba(255, 255, 255, 0.4);
    box-shadow: 0 0 12px rgba(255, 255, 255, 0.2);
}
.desktop-icon.hovered.selected {
    background-color: rgba(255, 255, 255, 0.2);
    border-color: rgba(255, 255, 255, 0.4);
    box-shadow: 0 0 15px rgba(255, 255, 255, 0.3);
}
.desktop-icon label {
    color: white;
    text-shadow: 2px 2px 6px black;
    opacity: 0.8;
    transition: opacity 200ms ease-in-out;
}
.desktop-icon.hovered label, .desktop-icon.selected label {
    opacity: 1.0;
}
menu.desktop-context-menu {
    background-color: #2d2d2d;
    border: 1px solid #555;
    border-radius: 8px;
    padding: 4px 0px;
}
menu.desktop-context-menu menuitem {
    color: #e0e0e0;
    padding: 6px 20px;
    min-height: 20px;
    transition: background-color 0.15s ease-in-out, color 0.15s ease-in-out;
}
menu.desktop-context-menu menuitem:hover {
    background-color: #4287f5;
    color: white;
}
"""

# Default action mode for each Drag & Drop case between Desktop and Thunar.
# Can be changed via the [Actions] section in the config file - no code
# changes needed. Valid values: copy, link, cut, none.
VALID_ACTION_MODES = ('copy', 'link', 'cut', 'none')
DEFAULT_ACTIONS = {
    'drop_in_folder': 'link',
    'drop_in_file': 'copy',
    'drag_out_file': 'cut',
    'drag_out_folder': 'copy',
}
ACTION_MODES = dict(DEFAULT_ACTIONS)

ACTIONS_CONFIG_BLOCK = """[Actions]
# Drag & Drop behavior between Desktop and Thunar.
# Valid values: copy, link, cut, none
#   copy = duplicate the file/folder
#   link = create a symlink (drop_in_* only)
#   cut  = move it (removes the original after the transfer)
#   none = do nothing / disable this action
#
# drop_in_folder: a FOLDER dragged from Thunar onto the Desktop.
drop_in_folder = link

# drop_in_file: a FILE dragged from Thunar onto the Desktop.
drop_in_file = copy

# drag_out_file: a FILE on the Desktop dragged out to Thunar.
drag_out_file = cut

# drag_out_folder: a FOLDER on the Desktop dragged out to Thunar.
drag_out_folder = copy
"""

DEFAULT_KEYBINDINGS = {
    'copy': '<Ctrl>c',
    'cut': '<Ctrl>x',
    'paste': '<Ctrl>v',
    'trash': 'Delete',
    'rename': 'F2',
    'open': 'Return',
    'select_all': '<Ctrl>a'
}
KEYBINDINGS = dict(DEFAULT_KEYBINDINGS)

KEYBINDINGS_CONFIG_BLOCK = """[Keybindings]
# Keyboard shortcuts mapping. Supports <Ctrl>, <Shift>, <Alt> + key
copy = <Ctrl>c
cut = <Ctrl>x
paste = <Ctrl>v
trash = Delete
rename = F2
open = Return
select_all = <Ctrl>a
"""

SORT_BY = 'name'
SORT_REVERSE = False
FOLDERS_FIRST = True
SHOW_HOME = True
SHOW_TRASH = True
SHOW_COMPUTER = True
USER_DIRS_FIRST = True
SHOW_HIDDEN = False


################################################################################
# CONFIGURATION & UTILITIES
# These functions handle loading/saving configs, positions, and grid math.
################################################################################

def save_setting(key, value):
    try:
        if not os.path.exists(CONF_FILE):
            return
        with open(CONF_FILE, 'r') as f:
            lines = f.readlines()
            
        found = False
        for i, line in enumerate(lines):
            if line.strip().startswith(f"{key} ") or line.strip().startswith(f"{key}="):
                lines[i] = f"{key} = {value}\n"
                found = True
                break
                
        if not found:
            lines.append(f"{key} = {value}\n")
            
        with open(CONF_FILE, 'w') as f:
            f.writelines(lines)
    except Exception as e:
        print(f"Failed to save setting {key}: {e}")

def load_config():
    global ICON_SIZE, CELL_WIDTH, CELL_HEIGHT, ACTION_MODES, KEYBINDINGS
    global SORT_BY, SORT_REVERSE, FOLDERS_FIRST, SHOW_HOME, SHOW_TRASH, SHOW_COMPUTER
    global SHOW_HIDDEN, USER_DIRS_FIRST
    
    os.makedirs(CONFIG_DIR, exist_ok=True)
    config = configparser.ConfigParser()
    
    DEFAULT_SETTINGS_BLOCK = f"""[Settings]
# Desktop icon size
icon_size = {ICON_SIZE}

# Sort icons by: name, date, size, type
sort_by = {SORT_BY}

# Reverse the sorting order (True/False)
sort_reverse = {SORT_REVERSE}

# Show folders before files (True/False)
folders_first = {FOLDERS_FIRST}

# Show special user directories (Downloads, Documents, etc.) before normal folders (True/False)
user_dirs_first = {USER_DIRS_FIRST}

# Show Home icon (True/False)
show_home = {SHOW_HOME}

# Show Trash icon (True/False)
show_trash = {SHOW_TRASH}

# Show Computer/This PC icon (True/False)
show_computer = {SHOW_COMPUTER}

# Show hidden files starting with a dot (True/False)
show_hidden = {SHOW_HIDDEN}
"""

    if not os.path.exists(CONF_FILE):
        try:
            with open(CONF_FILE, 'w') as configfile:
                configfile.write(DEFAULT_SETTINGS_BLOCK)
                configfile.write("\n")
                configfile.write(ACTIONS_CONFIG_BLOCK)
                configfile.write("\n")
                configfile.write(KEYBINDINGS_CONFIG_BLOCK)
        except OSError as e:
            print(f"Failed to create config file {CONF_FILE}: {e}")
    else:
        try:
            config.read(CONF_FILE)
            append_blocks = []

            if 'Settings' in config:
                if 'icon_size' in config['Settings']:
                    ICON_SIZE = int(config['Settings']['icon_size'])
                if 'sort_by' in config['Settings']:
                    SORT_BY = config['Settings']['sort_by']
                if 'sort_reverse' in config['Settings']:
                    SORT_REVERSE = config['Settings'].getboolean('sort_reverse')
                if 'folders_first' in config['Settings']:
                    FOLDERS_FIRST = config['Settings'].getboolean('folders_first')
                if 'user_dirs_first' in config['Settings']:
                    USER_DIRS_FIRST = config['Settings'].getboolean('user_dirs_first')
                if 'show_home' in config['Settings']:
                    SHOW_HOME = config['Settings'].getboolean('show_home')
                if 'show_trash' in config['Settings']:
                    SHOW_TRASH = config['Settings'].getboolean('show_trash')
                if 'show_computer' in config['Settings']:
                    SHOW_COMPUTER = config['Settings'].getboolean('show_computer')
                if 'show_hidden' in config['Settings']:
                    SHOW_HIDDEN = config['Settings'].getboolean('show_hidden')
            else:
                append_blocks.append(DEFAULT_SETTINGS_BLOCK)

            if 'Actions' not in config:
                append_blocks.append(ACTIONS_CONFIG_BLOCK)
            else:
                for key in DEFAULT_ACTIONS:
                    if key in config['Actions']:
                        value = config['Actions'][key].strip().lower()
                        if value in VALID_ACTION_MODES:
                            ACTION_MODES[key] = value
                        else:
                            print(f"Invalid value '{value}' for '{key}' in {CONF_FILE}, "
                                  f"using default '{DEFAULT_ACTIONS[key]}'. "
                                  f"Valid values: {', '.join(VALID_ACTION_MODES)}")

            if 'Keybindings' not in config:
                append_blocks.append(KEYBINDINGS_CONFIG_BLOCK)
            else:
                for key in DEFAULT_KEYBINDINGS:
                    if key in config['Keybindings']:
                        KEYBINDINGS[key] = config['Keybindings'][key].strip()

            if append_blocks:
                try:
                    with open(CONF_FILE, 'a') as configfile:
                        for block in append_blocks:
                            configfile.write("\n" + block)
                except OSError as e:
                    print(f"Failed to upgrade config file {CONF_FILE}: {e}")
        except (ValueError, configparser.Error) as e:
            print(f"Failed to parse {CONF_FILE}, using defaults: {e}")

    CELL_WIDTH = max(100, ICON_SIZE + 44)
    CELL_HEIGHT = max(100, ICON_SIZE + 44)

load_config()

def load_positions():
    if not os.path.exists(POSITIONS_FILE):
        return {}
    try:
        with open(POSITIONS_FILE, "r") as positions_file:
            return json.load(positions_file)
    except (OSError, ValueError) as error:
        print(f"Failed to load positions from {POSITIONS_FILE}: {error}")
        return {}

def save_positions(positions):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(POSITIONS_FILE, "w") as positions_file:
        json.dump(positions, positions_file, indent=4)

def get_grid_pos(x, y):
    col = max(0, int((x - PADDING) / (CELL_WIDTH + PADDING)))
    row = max(0, int((y - PADDING) / (CELL_HEIGHT + PADDING)))
    return col, row


################################################################################
# FILE OPERATIONS & WAYLAND CLIPBOARD
# Handles copying, pasting, cutting, and dragging files.
################################################################################

def apply_drop_in_action(mode, source_path, dest_path):
    if mode == 'none':
        return False
    try:
        if mode == 'link':
            os.symlink(source_path, dest_path)
        elif mode == 'cut':
            shutil.move(source_path, dest_path)
        else:
            if os.path.isdir(source_path):
                shutil.copytree(source_path, dest_path)
            else:
                shutil.copy2(source_path, dest_path)
    except Exception as e:
        print(f"apply_drop_in_action('{mode}') failed for {source_path}: {e}")
        return False
    return os.path.exists(dest_path) or os.path.islink(dest_path)

def wl_copy_files(uris, action):
    payload = (action + "\n" + "\n".join(uris)).encode("utf-8")
    try:
        subprocess.run(
            ["wl-copy", "--type", "x-special/gnome-copied-files"],
            input=payload,
            timeout=2,
        )
        return True
    except FileNotFoundError:
        print("Cannot find 'wl-copy'. Please install wl-clipboard.")
        return False
    except Exception as e:
        print(f"Error copying to wl-clipboard: {e}")
        return False



################################################################################
# THUNAR CUSTOM ACTIONS INTEGRATION
# Parses and executes custom actions defined in Thunar (uca.xml).
################################################################################

def get_thunar_uca_path():
    config_home = os.environ.get("XDG_CONFIG_HOME")
    if config_home:
        p = os.path.join(config_home, "Thunar", "uca.xml")
        if os.path.exists(p):
            return p
    user_p = os.path.expanduser("~/.config/Thunar/uca.xml")
    if os.path.exists(user_p):
        return user_p
    sys_p = "/etc/xdg/Thunar/uca.xml"
    if os.path.exists(sys_p):
        return sys_p
    return None

def load_thunar_custom_actions():
    uca_path = get_thunar_uca_path()
    if not uca_path or not os.path.exists(uca_path):
        return []

    try:
        tree = ET.parse(uca_path)
        root = tree.getroot()
    except Exception as e:
        print(f"Failed to parse Thunar uca.xml: {e}")
        return []

    actions = []
    for act in root.findall("action"):
        name = (act.findtext("name") or "").strip()
        cmd = (act.findtext("command") or "").strip()
        if not name or not cmd:
            continue

        icon = (act.findtext("icon") or "").strip()
        submenu = (act.findtext("submenu") or "").strip()
        description = (act.findtext("description") or "").strip()
        patterns_str = (act.findtext("patterns") or "*").strip()
        range_str = (act.findtext("range") or "").strip()

        has_directories = act.find("directories") is not None
        has_audio = act.find("audio-files") is not None
        has_image = act.find("image-files") is not None
        has_text = act.find("text-files") is not None
        has_video = act.find("video-files") is not None
        has_other = act.find("other-files") is not None

        patterns = [p.strip() for p in patterns_str.split(";") if p.strip()] or ["*"]

        actions.append({
            "name": name,
            "command": cmd,
            "icon": icon,
            "submenu": submenu,
            "description": description,
            "patterns": patterns,
            "range": range_str,
            "directories": has_directories,
            "audio": has_audio,
            "image": has_image,
            "text": has_text,
            "video": has_video,
            "other": has_other,
        })
    return actions

def action_matches_target(action, paths, is_directory_background=False):
    count = len(paths)
    if count == 0:
        return False

    rng = action.get("range", "")
    if rng and rng != "*":
        if rng == "1" and count != 1:
            return False
        elif rng in (">1", "1+") and count <= 1:
            return False
        elif rng == "0..1" and count > 1:
            return False

    if is_directory_background:
        if not action.get("directories", False):
            return False
        dir_name = os.path.basename(paths[0])
        return any(fnmatch.fnmatch(dir_name, p) or p == "*" for p in action.get("patterns", ["*"]))

    for p in paths:
        fname = os.path.basename(p)
        if not any(fnmatch.fnmatch(fname, pat) for pat in action.get("patterns", ["*"])):
            return False

        if os.path.isdir(p):
            if not action.get("directories", False):
                return False
        else:
            matched_type = False
            mime, _ = mimetypes.guess_type(p)
            if not mime:
                try:
                    mime = Gio.content_type_guess(p)[0] or ""
                except Exception:
                    mime = ""

            if mime.startswith("audio/") and action.get("audio", False):
                matched_type = True
            elif mime.startswith("image/") and action.get("image", False):
                matched_type = True
            elif mime.startswith("video/") and action.get("video", False):
                matched_type = True
            elif (mime.startswith("text/") or any(k in mime for k in ("script", "json", "xml", "javascript", "x-yaml", "x-sh"))) and action.get("text", False):
                matched_type = True
            elif action.get("other", False):
                matched_type = True

            if not matched_type:
                return False

    return True

def expand_thunar_command(cmd_template, paths, is_directory_background=False):
    if not paths:
        return cmd_template

    f_val = shlex.quote(paths[0])
    F_val = " ".join(shlex.quote(p) for p in paths)

    uris = [Gio.File.new_for_path(p).get_uri() for p in paths]
    u_val = shlex.quote(uris[0])
    U_val = " ".join(shlex.quote(u) for u in uris)

    n_val = shlex.quote(os.path.basename(paths[0]))
    N_val = " ".join(shlex.quote(os.path.basename(p)) for p in paths)

    if is_directory_background:
        d_val = shlex.quote(paths[0])
        D_val = " ".join(shlex.quote(paths[0]) for _ in paths)
    else:
        d_val = shlex.quote(os.path.dirname(paths[0]))
        D_val = " ".join(shlex.quote(os.path.dirname(p)) for p in paths)

    result = cmd_template.replace("%%", "\x00PERCENT\x00")
    result = result.replace("%F", F_val)
    result = result.replace("%f", f_val)
    result = result.replace("%U", U_val)
    result = result.replace("%u", u_val)
    result = result.replace("%D", D_val)
    result = result.replace("%d", d_val)
    result = result.replace("%N", N_val)
    result = result.replace("%n", n_val)
    result = result.replace("\x00PERCENT\x00", "%")

    return result

def execute_thunar_action(cmd_template, paths, cwd=None, is_directory_background=False):
    cmd = expand_thunar_command(cmd_template, paths, is_directory_background)
    try:
        subprocess.Popen(cmd, shell=True, cwd=cwd)
    except Exception as e:
        print(f"Failed to execute Thunar action '{cmd}': {e}")

def build_thunar_menu_item(action, paths, is_directory_background=False, fallback_cwd=None):
    item = Gtk.MenuItem()
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

    icon_name = action.get("icon")
    if icon_name:
        if os.path.isabs(icon_name) and os.path.exists(icon_name):
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(icon_name, 16, 16, True)
                img = Gtk.Image.new_from_pixbuf(pixbuf)
                box.pack_start(img, False, False, 0)
            except Exception:
                pass
        else:
            theme = Gtk.IconTheme.get_default()
            if theme.has_icon(icon_name):
                img = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
                box.pack_start(img, False, False, 0)

    label = Gtk.Label(label=action.get("name", ""))
    box.pack_start(label, False, False, 0)
    item.add(box)

    desc = action.get("description")
    if desc:
        item.set_tooltip_text(desc)

    cwd = fallback_cwd
    if is_directory_background:
        cwd = paths[0]
    elif paths:
        cwd = paths[0] if os.path.isdir(paths[0]) else os.path.dirname(paths[0])

    item.connect("activate", lambda w, a=action: execute_thunar_action(
        a["command"], paths, cwd=cwd, is_directory_background=is_directory_background
    ))
    return item

def populate_thunar_actions_menu(menu, paths, is_directory_background=False, fallback_cwd=None):
    actions = load_thunar_custom_actions()
    matching = [
        act for act in actions
        if action_matches_target(act, paths, is_directory_background=is_directory_background)
    ]
    if not matching:
        return 0

    submenus = {}
    for act in matching:
        item = build_thunar_menu_item(act, paths, is_directory_background, fallback_cwd)
        sub_name = act.get("submenu")
        if sub_name:
            if sub_name not in submenus:
                sub_menu_widget = Gtk.Menu()
                sub_menu_widget.get_style_context().add_class('desktop-context-menu')
                sub_item = Gtk.MenuItem(label=sub_name)
                sub_item.set_submenu(sub_menu_widget)
                menu.append(sub_item)
                submenus[sub_name] = sub_menu_widget
            submenus[sub_name].append(item)
        else:
            menu.append(item)
    return len(matching)


################################################################################
# UI COMPONENT: DESKTOP ICON
# Represents a single icon on the desktop grid.
################################################################################

class DesktopIcon(Gtk.EventBox):
    def __init__(self, gio_file, gio_info):
        super().__init__()
        self.gio_file = gio_file
        self.gio_info = gio_info
        
        self.set_visible_window(True)
        self.get_style_context().add_class('desktop-icon')
        self.is_hovered = False
        self.is_selected = False
        
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.add(vbox)
        
        name = gio_info.get_display_name()
        gicon = gio_info.get_icon()
        self.is_desktop_file = name.endswith('.desktop')
        self.app_info = None

        file_path = self.gio_file.get_path()
        self.is_dir_icon = bool(file_path and os.path.isdir(file_path))
        if gio_info and gio_info.get_file_type() == Gio.FileType.SHORTCUT:
            self.is_dir_icon = True

        self.is_user_dir = False
        if self.is_dir_icon:
            dir_map = {
                GLib.UserDirectory.DIRECTORY_DOWNLOAD: 'folder-download',
                GLib.UserDirectory.DIRECTORY_DOCUMENTS: 'folder-documents',
                GLib.UserDirectory.DIRECTORY_PICTURES: 'folder-pictures',
                GLib.UserDirectory.DIRECTORY_MUSIC: 'folder-music',
                GLib.UserDirectory.DIRECTORY_VIDEOS: 'folder-videos',
                GLib.UserDirectory.DIRECTORY_TEMPLATES: 'folder-templates',
                GLib.UserDirectory.DIRECTORY_PUBLIC_SHARE: 'folder-publicshare',
            }
            real_path = os.path.realpath(file_path) if file_path else ""
            found_special = False
            for glib_dir, icon_name in dir_map.items():
                target_path = GLib.get_user_special_dir(glib_dir)
                if target_path and real_path == os.path.realpath(target_path):
                    gicon = Gio.ThemedIcon.new_from_names([icon_name, 'folder'])
                    found_special = True
                    self.is_user_dir = True
                    break
                    
            if not found_special:
                name_lower = name.lower()
                heuristics = {
                    'downloads': 'folder-download', 'tải về': 'folder-download',
                    'documents': 'folder-documents', 'tài liệu': 'folder-documents',
                    'pictures': 'folder-pictures', 'hình ảnh': 'folder-pictures',
                    'music': 'folder-music', 'âm nhạc': 'folder-music', 'nhạc': 'folder-music',
                    'videos': 'folder-videos', 'video': 'folder-videos',
                    'templates': 'folder-templates', 'mẫu': 'folder-templates',
                    'public': 'folder-publicshare', 'công khai': 'folder-publicshare',
                }
                if name_lower in heuristics:
                    gicon = Gio.ThemedIcon.new_from_names([heuristics[name_lower], 'folder'])
                    self.is_user_dir = True

        if self.is_desktop_file:
            if HAS_GIO_UNIX:
                self.app_info = GioUnix.DesktopAppInfo.new_from_filename(file_path)
            else:
                self.app_info = Gio.DesktopAppInfo.new_from_filename(file_path)
                
            if self.app_info:
                name = self.app_info.get_name()
                gicon = self.app_info.get_icon() or gicon

        self.image = Gtk.Image()
        self.fallback_gicon = gicon
        
        self._dbus_thumbnail_requested = False
        self.has_thumbnail = self._load_image(gicon, name)

        self.label = Gtk.Label(label=name)
        self.label.set_line_wrap(True)
        self.label.set_line_wrap_mode(gi.repository.Pango.WrapMode.WORD_CHAR)
        self.label.set_max_width_chars(10)
        self.label.set_ellipsize(gi.repository.Pango.EllipsizeMode.END)
        self.label.set_lines(2)
        
        self.label.set_justify(Gtk.Justification.CENTER)
        self.label.set_halign(Gtk.Align.CENTER)

        vbox.pack_start(self.image, True, True, 0)
        vbox.pack_start(self.label, False, False, 0)

        self._pending_collapse = False
        self._drag_started = False

        self.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK |
            Gdk.EventMask.BUTTON_RELEASE_MASK |
            Gdk.EventMask.ENTER_NOTIFY_MASK |
            Gdk.EventMask.LEAVE_NOTIFY_MASK
        )
        self.connect("button-press-event", self.on_button_press)
        self.connect("button-release-event", self.on_button_release)
        self.connect("enter-notify-event", self.on_enter_notify)
        self.connect("leave-notify-event", self.on_leave_notify)
        
        outbound_key = 'drag_out_folder' if self.is_dir_icon else 'drag_out_file'
        self.outbound_mode = ACTION_MODES.get(outbound_key, DEFAULT_ACTIONS[outbound_key])

        drag_action_map = {
            'copy': Gdk.DragAction.COPY,
            'cut': Gdk.DragAction.MOVE,
            'link': Gdk.DragAction.LINK,
        }
        
        is_virtual = self.gio_file.get_uri().startswith("virtual://")
        
        if not is_virtual and self.outbound_mode in drag_action_map:
            self.drag_source_set(Gdk.ModifierType.BUTTON1_MASK, [], drag_action_map[self.outbound_mode])
            self.drag_source_add_uri_targets()
            self.connect("drag-data-get", self.on_drag_data_get)
            self.connect("drag-begin", self.on_drag_begin)
            self.connect("drag-data-delete", self.on_drag_data_delete)
            self.connect("drag-end", self.on_drag_end)
        
        self.show_all()

    def _load_image(self, gicon, name):
        if gicon:
            self.image.set_from_gicon(gicon, Gtk.IconSize.DIALOG)
            self.image.set_pixel_size(ICON_SIZE)

        def _apply_pixbuf(pixbuf):
            self.image.set_from_pixbuf(pixbuf)
            self.has_thumbnail = True

        def _async_load():
            files = [self.gio_file]
            file_path = self.gio_file.get_path()
            if file_path and os.path.islink(file_path):
                target_file = Gio.File.new_for_path(os.path.realpath(file_path))
                files.append(target_file)

            for thumbnail_file in files:
                try:
                    info_thumb = thumbnail_file.query_info(
                        "thumbnail::path,thumbnail::is-valid",
                        Gio.FileQueryInfoFlags.NONE,
                        None,
                    )
                    if info_thumb.has_attribute("thumbnail::path"):
                        is_valid = not info_thumb.has_attribute("thumbnail::is-valid") or info_thumb.get_attribute_boolean("thumbnail::is-valid")
                        if is_valid:
                            thumb_path = info_thumb.get_attribute_byte_string("thumbnail::path")
                            if isinstance(thumb_path, bytes):
                                thumb_path = thumb_path.decode("utf-8")
                            if thumb_path and os.path.exists(thumb_path):
                                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(thumb_path, ICON_SIZE, ICON_SIZE, True)
                                GLib.idle_add(_apply_pixbuf, pixbuf)
                                return
                except Exception:
                    pass 

            uris = [thumbnail_file.get_uri() for thumbnail_file in files]
            thumb_sizes_and_dirs = [
                ('large', '~/.cache/thumbnails/large'),
                ('normal', '~/.cache/thumbnails/normal'),
                ('large', '~/.thumbnails/large'),
                ('normal', '~/.thumbnails/normal')
            ]
            
            for uri in uris:
                uri_md5 = hashlib.md5(uri.encode('utf-8')).hexdigest()
                for _, base_dir in thumb_sizes_and_dirs:
                    thumb_path = os.path.expanduser(f'{base_dir}/{uri_md5}.png')
                    if os.path.exists(thumb_path):
                        try:
                            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(thumb_path, ICON_SIZE, ICON_SIZE, True)
                            GLib.idle_add(_apply_pixbuf, pixbuf)
                            return
                        except Exception:
                            pass

            if file_path:
                try:
                    content_type = self.gio_info.get_content_type()
                    if content_type and content_type.startswith("image/"):
                        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(file_path, ICON_SIZE, ICON_SIZE, True)
                        GLib.idle_add(_apply_pixbuf, pixbuf)
                        return
                except Exception:
                    pass
                        
            if not self._dbus_thumbnail_requested:
                if not self.is_dir_icon and not self.gio_file.get_uri().startswith("virtual://"):
                    try:
                        mime_type = self.gio_info.get_content_type()
                        if mime_type and (mime_type.startswith("image/") or mime_type.startswith("video/") or mime_type == "application/pdf"):
                            self._dbus_thumbnail_requested = True
                            GLib.idle_add(self._request_system_thumbnail)
                            GLib.idle_add(self._start_dbus_poll)
                    except Exception:
                        pass

        import threading
        threading.Thread(target=_async_load, daemon=True).start()
        return False

    def _start_dbus_poll(self):
        self._dbus_poll_attempts = 0
        GLib.timeout_add(1500, self._dbus_poll_tick)
        
    def _dbus_poll_tick(self):
        if self.has_thumbnail or self._dbus_poll_attempts >= 10:
            return False
            
        def _apply_pixbuf(pixbuf):
            self.image.set_from_pixbuf(pixbuf)
            self.has_thumbnail = True
            
        def _check_cache():
            uris = [self.gio_file.get_uri()]
            file_path = self.gio_file.get_path()
            if file_path and os.path.islink(file_path):
                uris.append(Gio.File.new_for_path(os.path.realpath(file_path)).get_uri())
                
            thumb_sizes_and_dirs = [
                ('large', '~/.cache/thumbnails/large'),
                ('normal', '~/.cache/thumbnails/normal'),
            ]
            
            for uri in uris:
                uri_md5 = hashlib.md5(uri.encode('utf-8')).hexdigest()
                for _, base_dir in thumb_sizes_and_dirs:
                    thumb_path = os.path.expanduser(f'{base_dir}/{uri_md5}.png')
                    if os.path.exists(thumb_path):
                        try:
                            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(thumb_path, ICON_SIZE, ICON_SIZE, True)
                            GLib.idle_add(_apply_pixbuf, pixbuf)
                            return
                        except Exception:
                            pass
                            
        import threading
        threading.Thread(target=_check_cache, daemon=True).start()
        self._dbus_poll_attempts += 1
        return True

    def _request_system_thumbnail(self):
        uri = self.gio_file.get_uri()
        mime_type = self.gio_info.get_content_type()
        if not mime_type:
            return
            
        def _dbus_call():
            try:
                bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
                proxy = Gio.DBusProxy.new_sync(
                    bus, Gio.DBusProxyFlags.NONE, None,
                    "org.freedesktop.thumbnails.Thumbnailer1",
                    "/org/freedesktop/thumbnails/Thumbnailer1",
                    "org.freedesktop.thumbnails.Thumbnailer1",
                    None
                )
                proxy.call_sync(
                    "Queue",
                    GLib.Variant("(asasssu)", (
                        [uri],
                        [mime_type],
                        "normal",
                        "default",
                        0
                    )),
                    Gio.DBusCallFlags.NONE,
                    -1,
                    None
                )
            except Exception:
                pass
                
        import threading
        threading.Thread(target=_dbus_call, daemon=True).start()

    def refresh_thumbnail(self):
        self.has_thumbnail = self._load_image(
            self.fallback_gicon, self.label.get_text()
        )
        return self.has_thumbnail

    def _real_path(self):
        path = self.gio_file.get_path()
        if path and os.path.islink(path):
            return os.path.realpath(path)
        return path

    def _resolve_uri(self):
        path = self._real_path()
        if path:
            return Gio.File.new_for_path(path).get_uri()
        return self.gio_file.get_uri()

    def on_drag_data_get(self, widget, drag_context, data, info, time):
        parent = self.get_parent()
        if isinstance(parent, DesktopLayout) and self in parent.selected_icons and len(parent.selected_icons) > 1:
            same_type = [icon for icon in parent.selected_icons if icon.is_dir_icon == self.is_dir_icon]
            data.set_uris([icon._resolve_uri() for icon in same_type])
        else:
            data.set_uris([self._resolve_uri()])

    def on_drag_data_delete(self, widget, drag_context):
        window = self.get_toplevel()
        if getattr(window, '_internal_drop_handled', False):
            return

        parent = self.get_parent()
        if isinstance(parent, DesktopLayout) and self in parent.selected_icons and len(parent.selected_icons) > 1:
            targets = [icon for icon in parent.selected_icons if icon.is_dir_icon == self.is_dir_icon]
        else:
            targets = [self]
        for icon in targets:
            if icon.outbound_mode != 'cut':
                continue
            real_path = icon._real_path()
            link_path = icon.gio_file.get_path()
            try:
                if real_path and os.path.exists(real_path):
                    if os.path.isdir(real_path):
                        shutil.rmtree(real_path)
                    else:
                        os.remove(real_path)
            except Exception as e:
                print(f"Could not delete {real_path} after Cut: {e}")
            if link_path and link_path != real_path and os.path.islink(link_path):
                try:
                    os.remove(link_path)
                except Exception as e:
                    print(f"Could not delete symlink {link_path}: {e}")

    def on_enter_notify(self, widget, event):
        self.is_hovered = True
        self.get_style_context().add_class('hovered')
        return False

    def on_leave_notify(self, widget, event):
        self.is_hovered = False
        self.get_style_context().remove_class('hovered')
        return False

    def on_drag_begin(self, widget, drag_context):
        self._drag_started = True
        window = self.get_toplevel()
        
        window._internal_drop_handled = False
        
        parent = self.get_parent()
        if isinstance(parent, DesktopLayout) and self in parent.selected_icons and len(parent.selected_icons) > 1:
            window._multi_drag_paths = [icon.gio_file.get_path() for icon in parent.selected_icons]
        else:
            window._multi_drag_paths = [self.gio_file.get_path()]
        window._multi_drag_origin = self.gio_file.get_path()

        alloc = self.get_allocation()
        surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, alloc.width, alloc.height)
        cr = cairo.Context(surface)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)
        self.draw(cr)
        cr.set_operator(cairo.OPERATOR_DEST_IN)
        cr.set_source_rgba(0, 0, 0, 0.6)
        cr.paint()
        Gtk.drag_set_icon_surface(drag_context, surface)

    def on_drag_end(self, widget, drag_context):
        window = self.get_toplevel()
        window._multi_drag_paths = None
        window._multi_drag_origin = None
        if hasattr(window, '_internal_drop_handled'):
            window._internal_drop_handled = False

    def set_selected(self, selected):
        self.is_selected = selected
        ctx = self.get_style_context()
        if selected:
            ctx.add_class('selected')
        else:
            ctx.remove_class('selected')

    def on_button_press(self, widget, event):
        if event.button == 1 and event.type == Gdk.EventType.BUTTON_PRESS:
            # Force focus so window can capture key events
            self.get_toplevel().grab_focus()
            
            parent = self.get_parent()
            self._pending_collapse = False
            self._drag_started = False
            if isinstance(parent, DesktopLayout):
                ctrl = bool(event.state & Gdk.ModifierType.CONTROL_MASK)
                if ctrl:
                    parent.select_icon(self, ctrl=True)
                elif self in parent.selected_icons and len(parent.selected_icons) > 1:
                    self._pending_collapse = True
                else:
                    parent.select_icon(self, ctrl=False)
            return False
        if event.button == 1 and event.type == Gdk.EventType._2BUTTON_PRESS:
            self.launch()
            return True
        elif event.button == 3 and event.type == Gdk.EventType.BUTTON_PRESS:
            self.get_toplevel().grab_focus()
            parent = self.get_parent()
            if isinstance(parent, DesktopLayout):
                if not (self in parent.selected_icons and len(parent.selected_icons) > 1):
                    parent.select_icon(self, ctrl=False)
            self.show_context_menu(event)
            return True
        return False

    def on_button_release(self, widget, event):
        if event.button == 1 and self._pending_collapse and not self._drag_started:
            parent = self.get_parent()
            if isinstance(parent, DesktopLayout):
                parent.select_icon(self, ctrl=False)
        self._pending_collapse = False
        self._drag_started = False
        return False

    def launch(self, specific_app=None):
        if self.gio_info and self.gio_info.get_file_type() == Gio.FileType.SHORTCUT:
            target_uri = self.gio_info.get_attribute_string("standard::target-uri")
            if target_uri:
                try:
                    Gio.AppInfo.launch_default_for_uri(target_uri, None)
                except GLib.Error:
                    subprocess.Popen(['xdg-open', target_uri])
                return

        if specific_app:
            try:
                specific_app.launch([self.gio_file], None)
            except GLib.Error as e:
                print(f"Failed to launch app: {e}")
            return

        if self.app_info:
            try:
                self.app_info.launch([], None)
            except GLib.Error as e:
                print(f"Failed to launch app: {e}")
        else:
            try:
                info = self.gio_file.query_info(Gio.FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE, Gio.FileQueryInfoFlags.NONE, None)
                content_type = info.get_content_type()
                app = Gio.AppInfo.get_default_for_type(content_type, False)
                if app:
                    app.launch([self.gio_file], None)
                else:
                    subprocess.Popen(['xdg-open', self.gio_file.get_path()])
            except Exception as e:
                print(f"Failed to open file: {e}")

    def open_in_thunar(self, widget):
        path = self.gio_file.get_path()
        if not path:
            return
            
        if os.path.islink(path):
            path = os.path.realpath(path)
            
        try:
            subprocess.Popen(["thunar", path])
        except Exception as e:
            print(f"Failed to open in Thunar: {e}")

    def show_context_menu(self, event):
        parent = self.get_parent()
        if isinstance(parent, DesktopLayout) and self in parent.selected_icons and len(parent.selected_icons) > 1:
            parent.show_multi_selection_context_menu(event)
            return

        menu = Gtk.Menu()
        menu.get_style_context().add_class('desktop-context-menu')

        open_item = Gtk.MenuItem(label="Open")
        open_item.connect("activate", lambda w: self.launch())
        menu.append(open_item)
        
        is_virtual = self.gio_file.get_uri().startswith("virtual://")
        is_trash = self.gio_file.get_uri() == "virtual://trash"

        if not is_virtual:
            try:
                info = self.gio_file.query_info(Gio.FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE, Gio.FileQueryInfoFlags.NONE, None)
                content_type = info.get_content_type()
                apps = Gio.AppInfo.get_all_for_type(content_type)
                if apps and not self.is_desktop_file:
                    open_with_item = Gtk.MenuItem(label="Open With")
                    open_with_menu = Gtk.Menu()
                    open_with_menu.get_style_context().add_class('desktop-context-menu')
                    for app in apps:
                        app_item = Gtk.MenuItem(label=app.get_display_name())
                        app_item.connect("activate", lambda w, a=app: self.launch(a))
                        open_with_menu.append(app_item)
                    open_with_item.set_submenu(open_with_menu)
                    menu.append(open_with_item)
            except Exception:
                pass

        if not is_virtual:
            thunar_item = Gtk.MenuItem(label="Open in Thunar")
            thunar_item.connect("activate", self.open_in_thunar)
            menu.append(thunar_item)

            file_path = self.gio_file.get_path()
            if file_path:
                populate_thunar_actions_menu(menu, [file_path], is_directory_background=False, fallback_cwd=os.path.dirname(file_path))
            
            menu.append(Gtk.SeparatorMenuItem())

            cut_item = Gtk.MenuItem(label="Cut")
            cut_item.connect("activate", lambda w: self.copy_to_clipboard("cut"))
            menu.append(cut_item)

            copy_item = Gtk.MenuItem(label="Copy")
            copy_item.connect("activate", lambda w: self.copy_to_clipboard("copy"))
            menu.append(copy_item)
            
            menu.append(Gtk.SeparatorMenuItem())

            rename_item = Gtk.MenuItem(label="Rename")
            rename_item.connect("activate", self.on_rename)
            menu.append(rename_item)

            trash_item = Gtk.MenuItem(label="Move to Trash")
            trash_item.connect("activate", self.move_to_trash)
            menu.append(trash_item)
            
        elif is_trash:
            menu.append(Gtk.SeparatorMenuItem())
            empty_item = Gtk.MenuItem(label="Empty Trash")
            def empty_trash(w):
                try:
                    subprocess.run(['gio', 'trash', '--empty'], timeout=5)
                except Exception:
                    pass
                self.image.set_from_icon_name("user-trash", Gtk.IconSize.DIALOG)
                self.image.set_pixel_size(ICON_SIZE)
                self.fallback_gicon = Gio.ThemedIcon.new_from_names(["user-trash"])
            empty_item.connect("activate", empty_trash)
            menu.append(empty_item)

        if not is_virtual:
            menu.append(Gtk.SeparatorMenuItem())
            prop_item = Gtk.MenuItem(label="Properties")
            prop_item.connect("activate", self.show_properties)
            menu.append(prop_item)

        menu.show_all()
        menu.popup_at_pointer(event)

    def copy_to_clipboard(self, action):
        wl_copy_files([self.gio_file.get_uri()], action)

    def on_rename(self, widget):
        dialog = Gtk.Dialog(title="Rename File", flags=Gtk.DialogFlags.MODAL)
        dialog.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_OK, Gtk.ResponseType.OK)
        dialog.set_default_size(300, -1)
        dialog.set_position(Gtk.WindowPosition.CENTER)
        
        entry = Gtk.Entry()
        entry.set_text(self.gio_info.get_display_name())
        entry.connect("activate", lambda e: dialog.response(Gtk.ResponseType.OK))
        
        box = dialog.get_content_area()
        box.pack_start(entry, True, True, 10)
        box.set_spacing(10)
        box.set_margin_left(15)
        box.set_margin_right(15)
        box.set_margin_bottom(10)
        
        dialog.show_all()
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            new_name = entry.get_text()
            if new_name and new_name != self.gio_info.get_display_name():
                try:
                    self.gio_file.set_display_name(new_name, None)
                except Exception as e:
                    print(f"Rename failed: {e}")
        dialog.destroy()

    def show_properties(self, widget):
        uri = self.gio_file.get_uri()
        cmd = [
            "dbus-send", 
            "--session", 
            "--dest=org.freedesktop.FileManager1",
            "--type=method_call", 
            "/org/freedesktop/FileManager1",
            "org.freedesktop.FileManager1.ShowItemProperties",
            f"array:string:{uri}", 
            "string:"
        ]
        try:
            subprocess.Popen(cmd)
        except Exception as e:
            print(f"Failed to open properties dialog: {e}")

    def move_to_trash(self, widget=None):
        try:
            self.gio_file.trash(None)
        except GLib.Error as e:
            print(f"Failed to trash file: {e}")


################################################################################
# UI COMPONENT: DESKTOP LAYOUT (GRID)
# Manages the layout, rubber-band selection, and drop zones.
################################################################################

class DesktopLayout(Gtk.Fixed):
    def __init__(self, window):
        super().__init__()
        self.window = window
        self.icons = {}
        self.selected_icons = set()
        self.drop_target_cell = None

        self._rubber_start = None
        self._rubber_active = False
        self._rubber_ctrl = False
        self._rubber_pre_selection = set()
        self.rubber_band_rect = None
        self._icon_alloc_cache = None
        
        self.desktop_dir = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DESKTOP)
        if not self.desktop_dir:
            self.desktop_dir = os.path.join(GLib.get_home_dir(), "Desktop")
        
        self.last_alloc_width = 0
        self.last_alloc_height = 0
        
        self.set_has_window(True)
        self.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK |
            Gdk.EventMask.BUTTON_RELEASE_MASK |
            Gdk.EventMask.POINTER_MOTION_MASK |
            Gdk.EventMask.ENTER_NOTIFY_MASK |
            Gdk.EventMask.LEAVE_NOTIFY_MASK
        )
        self.connect("button-press-event", self.on_bg_click)
        self.connect("button-release-event", self.on_bg_release)
        self.connect("motion-notify-event", self.on_bg_motion)
        self.connect("leave-notify-event", self.on_bg_leave)
        self.connect("enter-notify-event", self.on_bg_enter)
        
        self.connect("size-allocate", self.on_size_allocate)
        self.connect("draw", self.on_draw_overlay)
        self.cols = 1
        self.rows = 1

    def on_bg_enter(self, widget, event):
        if event.detail != Gdk.NotifyType.INFERIOR and event.mode == Gdk.CrossingMode.NORMAL:
            try:
                GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.ON_DEMAND)
            except AttributeError:
                pass
        return False

    def on_bg_leave(self, widget, event):
        if event.detail != Gdk.NotifyType.INFERIOR and event.mode == Gdk.CrossingMode.NORMAL:
            self.clear_selection()
            self.window.set_focus(None)
            try:
                GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)
            except AttributeError:
                pass
        return False

    def on_bg_click(self, widget, event):
        if event.window != self.get_window():
            return False
        
        self.window.grab_focus()
        
        if event.button == 1:
            self._rubber_start = (event.x, event.y)
            self._rubber_active = False
            self._rubber_ctrl = bool(event.state & Gdk.ModifierType.CONTROL_MASK)
            self._rubber_pre_selection = set(self.selected_icons) if self._rubber_ctrl else set()
            
            self._icon_alloc_cache = []
            for icon in self.icons.values():
                alloc = icon.get_allocation()
                self._icon_alloc_cache.append((icon, alloc.x, alloc.y, alloc.x + alloc.width, alloc.y + alloc.height))
        elif event.button == 3:
            self.clear_selection()
            self.show_desktop_context_menu(event)
        return False

    def on_bg_motion(self, widget, event):
        if self._rubber_start is None:
            return False
        if not (event.state & Gdk.ModifierType.BUTTON1_MASK):
            return False

        sx, sy = self._rubber_start
        dx, dy = event.x - sx, event.y - sy

        if not self._rubber_active and (abs(dx) > 4 or abs(dy) > 4):
            self._rubber_active = True

        if self._rubber_active:
            x0, y0 = min(sx, event.x), min(sy, event.y)
            x1, y1 = max(sx, event.x), max(sy, event.y)
            
            old_rect = self.rubber_band_rect
            self.rubber_band_rect = (x0, y0, x1 - x0, y1 - y0)

            in_rect = self._icons_in_rect(x0, y0, x1, y1)
            self._apply_selection(self._rubber_pre_selection | in_rect)
            
            if old_rect:
                ox, oy, ow, oh = old_rect
                ux = min(x0, ox) - 2
                uy = min(y0, oy) - 2
                uw = max(x0 + (x1 - x0), ox + ow) - ux + 4
                uh = max(y0 + (y1 - y0), oy + oh) - uy + 4
                self.queue_draw_area(int(ux), int(uy), int(uw), int(uh))
            else:
                self.queue_draw_area(int(x0 - 2), int(y0 - 2), int(x1 - x0 + 4), int(y1 - y0 + 4))
        return False

    def on_bg_release(self, widget, event):
        if event.button == 1 and self._rubber_start is not None:
            if not self._rubber_active and not self._rubber_ctrl:
                self.clear_selection()
            
            old_rect = self.rubber_band_rect
            
            self._rubber_start = None
            self._rubber_active = False
            self.rubber_band_rect = None
            self._icon_alloc_cache = None
            
            if old_rect:
                ox, oy, ow, oh = old_rect
                self.queue_draw_area(int(ox - 2), int(oy - 2), int(ow + 4), int(oh + 4))
            else:
                self.queue_draw()
        return False

    def _icons_in_rect(self, x0, y0, x1, y1):
        result = set()
        if self._icon_alloc_cache is not None:
            for icon, ix0, iy0, ix1, iy1 in self._icon_alloc_cache:
                if ix0 < x1 and ix1 > x0 and iy0 < y1 and iy1 > y0:
                    result.add(icon)
        else:
            for icon in self.icons.values():
                alloc = icon.get_allocation()
                ix0, iy0 = alloc.x, alloc.y
                ix1, iy1 = ix0 + alloc.width, iy0 + alloc.height
                if ix0 < x1 and ix1 > x0 and iy0 < y1 and iy1 > y0:
                    result.add(icon)
        return result

    def _apply_selection(self, desired_set):
        for icon in list(self.selected_icons):
            if icon not in desired_set:
                icon.set_selected(False)
                self.selected_icons.discard(icon)
        for icon in desired_set:
            if icon not in self.selected_icons:
                icon.set_selected(True)
                self.selected_icons.add(icon)

    def on_key_press(self, widget, event):
        keyname = Gdk.keyval_name(event.keyval)
        if not keyname:
            return False
            
        mods = []
        if event.state & Gdk.ModifierType.CONTROL_MASK:
            mods.append("<Ctrl>")
        if event.state & Gdk.ModifierType.SHIFT_MASK:
            mods.append("<Shift>")
        if event.state & Gdk.ModifierType.MOD1_MASK:
            mods.append("<Alt>")
            
        combo = "".join(mods) + (keyname.lower() if len(keyname) == 1 else keyname)
        
        action = None
        for k, v in KEYBINDINGS.items():
            if v == combo:
                action = k
                break
                
        if not action:
            return False
            
        if action == 'copy':
            self.copy_selected_to_clipboard('copy')
            return True
        elif action == 'cut':
            self.copy_selected_to_clipboard('cut')
            return True
        elif action == 'paste':
            self.on_paste(None)
            return True
        elif action == 'trash':
            self.trash_selected()
            return True
        elif action == 'rename':
            self.rename_selected()
            return True
        elif action == 'open':
            self.launch_selected()
            return True
        elif action == 'select_all':
            self.select_all_icons()
            return True
            
        return False

    def select_all_icons(self):
        for icon in self.icons.values():
            if icon not in self.selected_icons:
                icon.set_selected(True)
                self.selected_icons.add(icon)

    def rename_selected(self):
        if len(self.selected_icons) == 1:
            list(self.selected_icons)[0].on_rename(None)

    def sort_icons(self, criterion=None, reverse=None):
        global SORT_BY, SORT_REVERSE, FOLDERS_FIRST
        if criterion is not None:
            SORT_BY = criterion
        if reverse is not None:
            SORT_REVERSE = reverse
            
        save_setting('sort_by', SORT_BY)
        save_setting('sort_reverse', SORT_REVERSE)
        save_setting('folders_first', FOLDERS_FIRST)

        icon_list = []
        for filepath, icon_widget in self.icons.items():
            filename = os.path.basename(filepath)
            try:
                if filepath.startswith("virtual://"):
                    mod_time = 0
                    size = 0
                else:
                    st = os.stat(filepath)
                    mod_time = st.st_mtime
                    size = st.st_size
            except OSError:
                mod_time = 0
                size = 0
                
            is_dir = icon_widget.is_dir_icon
            ext = os.path.splitext(filename)[1].lower() if not is_dir else ""
            name_lower = filename.lower()
            type_key = (ext, name_lower)
            
            icon_list.append({
                'filepath': filepath,
                'filename': filename,
                'name': name_lower,
                'date': mod_time,
                'size': size,
                'type': type_key,
                'is_dir': is_dir,
                'is_user_dir': getattr(icon_widget, 'is_user_dir', False),
                'icon_widget': icon_widget
            })
            
        def get_sort_val(x):
            if SORT_BY == 'name':
                return x['name']
            elif SORT_BY == 'date':
                return x['date']
            elif SORT_BY == 'size':
                return x['size']
            elif SORT_BY == 'type':
                return x['type']
            return x['name']
            
        virtual_icons = [x for x in icon_list if x['filepath'].startswith("virtual://")]
        normal_icons = [x for x in icon_list if not x['filepath'].startswith("virtual://")]

        if USER_DIRS_FIRST:
            user_dirs = [x for x in normal_icons if x['is_dir'] and x.get('is_user_dir', False)]
            other_icons = [x for x in normal_icons if not (x['is_dir'] and x.get('is_user_dir', False))]
            
            user_dirs.sort(key=get_sort_val, reverse=SORT_REVERSE)

            if FOLDERS_FIRST:
                folders = [x for x in other_icons if x['is_dir']]
                files = [x for x in other_icons if not x['is_dir']]
                folders.sort(key=get_sort_val, reverse=SORT_REVERSE)
                files.sort(key=get_sort_val, reverse=SORT_REVERSE)
                other_icons = folders + files
            else:
                other_icons.sort(key=get_sort_val, reverse=SORT_REVERSE)
                
            normal_icons = user_dirs + other_icons
        else:
            if FOLDERS_FIRST:
                folders = [x for x in normal_icons if x['is_dir']]
                files = [x for x in normal_icons if not x['is_dir']]
                folders.sort(key=get_sort_val, reverse=SORT_REVERSE)
                files.sort(key=get_sort_val, reverse=SORT_REVERSE)
                normal_icons = folders + files
            else:
                normal_icons.sort(key=get_sort_val, reverse=SORT_REVERSE)
            
        order = {"virtual://home": 0, "virtual://computer": 1, "virtual://trash": 2}
        virtual_icons.sort(key=lambda x: order.get(x['filepath'], 99))
        
        final_list = virtual_icons + normal_icons
            
        self.cols = max(1, (self.last_alloc_width - PADDING) // (CELL_WIDTH + PADDING))
        self.rows = max(1, (self.last_alloc_height - PADDING) // (CELL_HEIGHT + PADDING))
        
        positions = load_positions()
        for index, item in enumerate(final_list):
            c = index // self.rows
            r = index % self.rows
            c = min(c, self.cols - 1)
            r = min(r, self.rows - 1)
            positions[item['filename']] = {'col': c, 'row': r}
            
        save_positions(positions)
        self.reposition_icons()

    def show_desktop_context_menu(self, event):
        menu = Gtk.Menu()
        menu.get_style_context().add_class('desktop-context-menu')

        reload_item = Gtk.MenuItem(label="Reload")
        reload_item.connect("activate", self.on_reload)
        menu.append(reload_item)

        menu.append(Gtk.SeparatorMenuItem())

        sort_item = Gtk.MenuItem(label="Sort By")
        sort_menu = Gtk.Menu()
        sort_menu.get_style_context().add_class('desktop-context-menu')
        
        sort_opts = [
            ("Name (A-Z)", 'name', False),
            ("Name (Z-A)", 'name', True),
            ("Date Modified (Newest)", 'date', True),
            ("Date Modified (Oldest)", 'date', False),
            ("Size (Largest)", 'size', True),
            ("Size (Smallest)", 'size', False),
            ("Type", 'type', False)
        ]
        
        first_radio = None
        for label, criterion, reverse in sort_opts:
            if first_radio is None:
                item = Gtk.RadioMenuItem.new_with_label(None, label)
                first_radio = item
            else:
                item = Gtk.RadioMenuItem.new_with_label_from_widget(first_radio, label)
            
            if SORT_BY == criterion and SORT_REVERSE == reverse:
                item.set_active(True)
                
            def make_toggled_cb(crit, rev):
                def cb(w):
                    if w.get_active():
                        self.sort_icons(crit, rev)
                return cb
                
            item.connect("toggled", make_toggled_cb(criterion, reverse))
            sort_menu.append(item)

        sort_menu.append(Gtk.SeparatorMenuItem())
        
        folders_first_item = Gtk.CheckMenuItem(label="Folders First")
        folders_first_item.set_active(FOLDERS_FIRST)
        def on_folders_first_toggled(widget):
            global FOLDERS_FIRST
            FOLDERS_FIRST = widget.get_active()
            save_setting('folders_first', FOLDERS_FIRST)
            self.sort_icons()
        folders_first_item.connect("toggled", on_folders_first_toggled)
        sort_menu.append(folders_first_item)

        user_dirs_first_item = Gtk.CheckMenuItem(label="User Dirs First")
        user_dirs_first_item.set_active(USER_DIRS_FIRST)
        def on_user_dirs_first_toggled(widget):
            global USER_DIRS_FIRST
            USER_DIRS_FIRST = widget.get_active()
            save_setting('user_dirs_first', USER_DIRS_FIRST)
            self.sort_icons()
        user_dirs_first_item.connect("toggled", on_user_dirs_first_toggled)
        sort_menu.append(user_dirs_first_item)

        sort_item.set_submenu(sort_menu)
        menu.append(sort_item)

        menu.append(Gtk.SeparatorMenuItem())
        
        icons_item = Gtk.MenuItem(label="Desktop Icons")
        icons_menu = Gtk.Menu()
        icons_menu.get_style_context().add_class('desktop-context-menu')
        
        def toggle_special(key, widget):
            save_setting(key, widget.get_active())
            self.on_reload(None)
            
        home_item = Gtk.CheckMenuItem(label="Home")
        home_item.set_active(SHOW_HOME)
        home_item.connect("toggled", lambda w: toggle_special('show_home', w))
        icons_menu.append(home_item)
        
        trash_item = Gtk.CheckMenuItem(label="Trash")
        trash_item.set_active(SHOW_TRASH)
        trash_item.connect("toggled", lambda w: toggle_special('show_trash', w))
        icons_menu.append(trash_item)
        
        comp_item = Gtk.CheckMenuItem(label="This PC")
        comp_item.set_active(SHOW_COMPUTER)
        comp_item.connect("toggled", lambda w: toggle_special('show_computer', w))
        icons_menu.append(comp_item)
        
        icons_menu.append(Gtk.SeparatorMenuItem())
        
        hidden_item = Gtk.CheckMenuItem(label="Show Hidden Files")
        hidden_item.set_active(SHOW_HIDDEN)
        hidden_item.connect("toggled", lambda w: toggle_special('show_hidden', w))
        icons_menu.append(hidden_item)
        
        icons_item.set_submenu(icons_menu)
        menu.append(icons_item)

        menu.append(Gtk.SeparatorMenuItem())

        create_folder_item = Gtk.MenuItem(label="Create Folder")
        create_folder_item.connect("activate", lambda w: self._prompt_create("Create Folder", True))
        menu.append(create_folder_item)

        create_doc_item = Gtk.MenuItem(label="Create Document")
        create_doc_item.connect("activate", lambda w: self._prompt_create("Create Empty File", False))
        menu.append(create_doc_item)
        
        menu.append(Gtk.SeparatorMenuItem())

        paste_item = Gtk.MenuItem(label="Paste")
        paste_item.connect("activate", self.on_paste)
        menu.append(paste_item)
        
        menu.append(Gtk.SeparatorMenuItem())

        added_actions = populate_thunar_actions_menu(
            menu, [self.desktop_dir], is_directory_background=True, fallback_cwd=self.desktop_dir
        )
        if added_actions == 0:
            term_item = Gtk.MenuItem(label="Open Terminal Here")
            term_item.connect("activate", self.on_open_terminal)
            menu.append(term_item)
        
        menu.append(Gtk.SeparatorMenuItem())

        thunar_item = Gtk.MenuItem(label="Open in Thunar")
        thunar_item.connect("activate", lambda w: subprocess.Popen(["thunar", self.desktop_dir]))
        menu.append(thunar_item)

        menu.append(Gtk.SeparatorMenuItem())
        
        settings_item = Gtk.MenuItem(label="Settings")
        settings_menu = Gtk.Menu()
        settings_menu.get_style_context().add_class('desktop-context-menu')
        
        default_app_item = Gtk.MenuItem(label="Open with Default App")
        def open_default_cb(w):
            try:
                subprocess.Popen(["xdg-open", CONF_FILE])
            except Exception as e:
                print(f"Failed to open default app: {e}")
        default_app_item.connect("activate", open_default_cb)
        settings_menu.append(default_app_item)
        
        editors = ["nano", "vim", "nvim", "vi", "micro"]
        found_editors = [ed for ed in editors if shutil.which(ed)]
        if found_editors:
            settings_menu.append(Gtk.SeparatorMenuItem())
            for ed in found_editors:
                ed_item = Gtk.MenuItem(label=f"Open with {ed}")
                
                def make_editor_cb(editor_cmd):
                    def cb(w):
                        terminals = [
                            ["kitty", "--"],
                            ["xfce4-terminal", "-x"],
                            ["gnome-terminal", "--"],
                            ["alacritty", "-e"],
                            ["x-terminal-emulator", "-e"],
                            ["exo-open", "--launch", "TerminalEmulator"]
                        ]
                        launched = False
                        for term in terminals:
                            if shutil.which(term[0]):
                                try:
                                    subprocess.Popen(term + [editor_cmd, CONF_FILE])
                                    launched = True
                                    break
                                except Exception as e:
                                    print(f"Failed to launch {term[0]}: {e}")
                        if not launched:
                            print(f"Could not find a suitable terminal emulator to launch {editor_cmd}")
                    return cb
                    
                ed_item.connect("activate", make_editor_cb(ed))
                settings_menu.append(ed_item)
        
        settings_item.set_submenu(settings_menu)
        menu.append(settings_item)

        menu.show_all()
        menu.popup_at_pointer(event)

    def on_reload(self, widget):
        import sys
        import os
        try:
            os.execv(sys.executable, [sys.executable] + sys.argv)
        except Exception as e:
            print(f"Failed to reload app: {e}")

    def _prompt_create(self, title, is_folder):
        dialog = Gtk.Dialog(title=title, flags=Gtk.DialogFlags.MODAL)
        dialog.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_OK, Gtk.ResponseType.OK)
        dialog.set_default_size(300, -1)
        dialog.set_position(Gtk.WindowPosition.CENTER)
        
        entry = Gtk.Entry()
        entry.set_text("New Folder" if is_folder else "New Document.txt")
        entry.connect("activate", lambda e: dialog.response(Gtk.ResponseType.OK))
        
        box = dialog.get_content_area()
        box.pack_start(entry, True, True, 10)
        box.set_spacing(10)
        box.set_margin_left(15)
        box.set_margin_right(15)
        box.set_margin_bottom(10)
        
        dialog.show_all()
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            name = entry.get_text()
            if name:
                path = os.path.join(self.desktop_dir, name)
                try:
                    if is_folder:
                        os.makedirs(path, exist_ok=True)
                    else:
                        open(path, 'a').close()
                except Exception as e:
                    print(f"Failed to create {path}: {e}")
        dialog.destroy()

    def on_paste(self, widget):
        try:
            result = subprocess.run(
                ["wl-paste", "--list-types"],
                capture_output=True, text=True, timeout=2
            )
            mime_types = [t.strip() for t in result.stdout.splitlines() if t.strip()]
        except FileNotFoundError:
            print("Cannot find 'wl-paste'. Please install wl-clipboard.")
            return
        except Exception as e:
            print(f"Could not read target list from wl-paste: {e}")
            return

        def execute_paste(paths, action):
            for item in paths:
                source_path = ""
                if item.startswith("file://"):
                    source_path = urllib.parse.unquote(item[7:])
                elif item.startswith("/"):
                    source_path = item
                else:
                    continue
                    
                if not source_path or not os.path.exists(source_path):
                    continue
                    
                dest_path = os.path.join(self.desktop_dir, os.path.basename(source_path))
                if os.path.exists(dest_path):
                    continue
                    
                try:
                    if action == "cut":
                        shutil.move(source_path, dest_path)
                    else:
                        if os.path.isdir(source_path):
                            shutil.copytree(source_path, dest_path)
                        else:
                            shutil.copy2(source_path, dest_path)
                except Exception as e:
                    print(f"Error pasting {source_path}: {e}")

        def read_mime(mime):
            try:
                r = subprocess.run(
                    ["wl-paste", "--type", mime, "--no-newline"],
                    capture_output=True, timeout=2
                )
                if r.returncode != 0 or not r.stdout:
                    return None
                return r.stdout
            except Exception as e:
                return None

        if "x-special/gnome-copied-files" in mime_types:
            raw = read_mime("x-special/gnome-copied-files")
            if raw:
                text = raw.decode("utf-8", errors="ignore").replace('\x00', '\n')
                lines = [line.strip() for line in text.splitlines() if line.strip()]
                if lines:
                    action = "copy"
                    paths = lines
                    if lines[0] in ("copy", "cut"):
                        action = lines[0]
                        paths = lines[1:]
                    execute_paste(paths, action)
                    return

        if "text/uri-list" in mime_types:
            raw = read_mime("text/uri-list")
            if raw:
                text = raw.decode("utf-8", errors="ignore")
                lines = [line.strip() for line in text.splitlines()
                         if line.strip() and not line.startswith('#')]
                if lines:
                    execute_paste(lines, "copy")
                    return

        for mime in ("text/plain;charset=utf-8", "UTF8_STRING", "text/plain", "STRING"):
            if mime in mime_types:
                raw = read_mime(mime)
                if raw:
                    text = raw.decode("utf-8", errors="ignore")
                    lines = [line.strip() for line in text.splitlines() if line.strip()]
                    if lines:
                        execute_paste(lines, "copy")
                        return

    def on_open_terminal(self, widget):
        try:
            subprocess.Popen(["exo-open", "--working-directory", self.desktop_dir, "--launch", "TerminalEmulator"])
        except Exception as e:
            print(f"Failed to open terminal: {e}")

    def add_icon(self, filepath, gio_info):
        if filepath in self.icons:
            return
        if filepath.startswith("virtual://"):
            gio_file = Gio.File.new_for_uri(filepath)
        else:
            gio_file = Gio.File.new_for_path(filepath)
        icon_widget = DesktopIcon(gio_file, gio_info)
        self.icons[filepath] = icon_widget
        self.put(icon_widget, -1000, -1000)
        GLib.idle_add(self.reposition_icons)

    def remove_icon(self, filepath):
        if filepath in self.icons:
            icon_widget = self.icons.pop(filepath)
            self.selected_icons.discard(icon_widget)
            self.remove(icon_widget)
            icon_widget.destroy()
            GLib.idle_add(self.reposition_icons)

    def on_size_allocate(self, widget, allocation):
        if allocation.width != self.last_alloc_width or allocation.height != self.last_alloc_height:
            self.last_alloc_width = allocation.width
            self.last_alloc_height = allocation.height
            GLib.idle_add(self.reposition_icons)

    def reposition_icons(self):
        if self.last_alloc_width < 200 or self.last_alloc_height < 200:
            return False

        self.cols = max(1, (self.last_alloc_width - PADDING) // (CELL_WIDTH + PADDING))
        self.rows = max(1, (self.last_alloc_height - PADDING) // (CELL_HEIGHT + PADDING))
        
        positions = load_positions()
        
        # If positions is completely empty (e.g. first run or reset), 
        # do a full sort to establish standard placement respecting user settings.
        if not positions and self.icons:
            # We must use idle_add to prevent recursion depth issues or blockages
            # but actually it's fine to call it directly if we return.
            # sort_icons will save positions and call reposition_icons again.
            self.sort_icons()
            return False
            
        occupied_cells = set()
        unpositioned_icons = []
        
        # 1. First assign fixed positions to virtual icons
        order = {"virtual://home": 0, "virtual://computer": 1, "virtual://trash": 2}
        virtuals = []
        normals = []
        for filepath, icon_widget in self.icons.items():
            if filepath.startswith("virtual://"):
                virtuals.append((filepath, icon_widget))
            else:
                normals.append((filepath, icon_widget))
                
        virtuals.sort(key=lambda x: order.get(x[0], 99))
        for index, (filepath, icon_widget) in enumerate(virtuals):
            filename = os.path.basename(filepath)
            icon_widget.set_size_request(CELL_WIDTH, CELL_HEIGHT)
            c = index // self.rows
            r = index % self.rows
            c = min(c, self.cols - 1)
            r = min(r, self.rows - 1)
            occupied_cells.add((c, r))
            x = PADDING + c * (CELL_WIDTH + PADDING)
            y = PADDING + r * (CELL_HEIGHT + PADDING)
            
            alloc = icon_widget.get_allocation()
            if alloc.x != x or alloc.y != y:
                self.move(icon_widget, x, y)
                
            if positions.get(filename) != {'col': c, 'row': r}:
                positions[filename] = {'col': c, 'row': r}
                
        # 2. Then assign remaining icons
        for filepath, icon_widget in normals:
            filename = os.path.basename(filepath)
            icon_widget.set_size_request(CELL_WIDTH, CELL_HEIGHT)
            
            if filename in positions and 'col' in positions[filename]:
                c = positions[filename]['col']
                r = positions[filename]['row']
                
                c = min(c, self.cols - 1)
                r = min(r, self.rows - 1)
                
                if (c, r) not in occupied_cells:
                    occupied_cells.add((c, r))
                    x = PADDING + c * (CELL_WIDTH + PADDING)
                    y = PADDING + r * (CELL_HEIGHT + PADDING)
                    
                    alloc = icon_widget.get_allocation()
                    if alloc.x != x or alloc.y != y:
                        self.move(icon_widget, x, y)
                    continue
            
            unpositioned_icons.append((filename, icon_widget))
                
        positions_changed = False
        
        def find_empty_spot():
            for c in range(self.cols):
                for r in range(self.rows):
                    if (c, r) not in occupied_cells:
                        return c, r
            return self.cols - 1, self.rows - 1
            
        for filename, icon_widget in unpositioned_icons:
            c, r = find_empty_spot()
            occupied_cells.add((c, r))
            
            x = PADDING + c * (CELL_WIDTH + PADDING)
            y = PADDING + r * (CELL_HEIGHT + PADDING)
            self.move(icon_widget, x, y)
            
            positions[filename] = {'col': c, 'row': r}
            positions_changed = True
            
        if positions_changed:
            save_positions(positions)
            
        return False

    def select_icon(self, icon_widget, ctrl=False):
        if ctrl:
            if icon_widget in self.selected_icons:
                icon_widget.set_selected(False)
                self.selected_icons.discard(icon_widget)
            else:
                icon_widget.set_selected(True)
                self.selected_icons.add(icon_widget)
        else:
            self.clear_selection()
            icon_widget.set_selected(True)
            self.selected_icons.add(icon_widget)

    def clear_selection(self):
        for icon in list(self.selected_icons):
            icon.set_selected(False)
        self.selected_icons.clear()

    def show_multi_selection_context_menu(self, event):
        menu = Gtk.Menu()
        menu.get_style_context().add_class('desktop-context-menu')
        count = len(self.selected_icons)

        open_item = Gtk.MenuItem(label=f"Open ({count} items)")
        open_item.connect("activate", lambda w: self.launch_selected())
        menu.append(open_item)

        paths = [
            icon.gio_file.get_path() for icon in self.selected_icons
            if icon.gio_file.get_path() and not icon.gio_file.get_uri().startswith("virtual://")
        ]
        if paths:
            populate_thunar_actions_menu(menu, paths, is_directory_background=False, fallback_cwd=self.desktop_dir)

        menu.append(Gtk.SeparatorMenuItem())

        cut_item = Gtk.MenuItem(label=f"Cut ({count} items)")
        cut_item.connect("activate", lambda w: self.copy_selected_to_clipboard("cut"))
        menu.append(cut_item)

        copy_item = Gtk.MenuItem(label=f"Copy ({count} items)")
        copy_item.connect("activate", lambda w: self.copy_selected_to_clipboard("copy"))
        menu.append(copy_item)

        menu.append(Gtk.SeparatorMenuItem())

        trash_item = Gtk.MenuItem(label=f"Move to Trash ({count} items)")
        trash_item.connect("activate", lambda w: self.trash_selected())
        menu.append(trash_item)

        menu.show_all()
        menu.popup_at_pointer(event)

    def launch_selected(self):
        for icon in list(self.selected_icons):
            icon.launch()

    def trash_selected(self):
        for icon in list(self.selected_icons):
            try:
                icon.gio_file.trash(None)
            except GLib.Error as e:
                print(f"Failed to trash {icon.gio_file.get_path()}: {e}")

    def copy_selected_to_clipboard(self, action):
        icons = list(self.selected_icons)
        if not icons:
            return
        uris = [icon.gio_file.get_uri() for icon in icons]
        wl_copy_files(uris, action)

    def set_drop_target(self, col, row):
        new_target = (col, row)
        if self.drop_target_cell != new_target:
            self.drop_target_cell = new_target
            self.queue_draw()

    def clear_drop_target(self):
        if self.drop_target_cell is not None:
            self.drop_target_cell = None
            self.queue_draw()

    def on_draw_overlay(self, widget, cr):
        if self.rubber_band_rect is not None:
            x, y, w, h = self.rubber_band_rect
            cr.set_source_rgba(1.0, 1.0, 1.0, 0.15)
            cr.rectangle(x, y, w, h)
            cr.fill()
            cr.set_source_rgba(1.0, 1.0, 1.0, 0.5)
            cr.set_line_width(1)
            cr.rectangle(x + 0.5, y + 0.5, max(w - 1, 0), max(h - 1, 0))
            cr.stroke()

        if self.drop_target_cell is None:
            return False

        col, row = self.drop_target_cell
        x = PADDING + col * (CELL_WIDTH + PADDING)
        y = PADDING + row * (CELL_HEIGHT + PADDING)

        cr.set_source_rgba(1.0, 1.0, 1.0, 0.1)
        self._draw_rounded_rect(cr, x, y, CELL_WIDTH, CELL_HEIGHT, 8)
        cr.fill()

        cr.set_source_rgba(1.0, 1.0, 1.0, 0.5)
        cr.set_dash([6, 4])
        cr.set_line_width(2)
        self._draw_rounded_rect(cr, x + 1, y + 1, CELL_WIDTH - 2, CELL_HEIGHT - 2, 8)
        cr.stroke()

        return False

    @staticmethod
    def _draw_rounded_rect(cr, x, y, w, h, r):
        cr.new_sub_path()
        cr.arc(x + w - r, y + r, r, -pi / 2, 0)
        cr.arc(x + w - r, y + h - r, r, 0, pi / 2)
        cr.arc(x + r, y + h - r, r, pi / 2, pi)
        cr.arc(x + r, y + r, r, pi, 3 * pi / 2)
        cr.close_path()


################################################################################
# DESKTOP MANAGER (CONTROLLER)
# Core controller that watches the file system and manages all icons.
################################################################################

class DesktopManager:
    def __init__(self, layouts):
        self.layouts = layouts
        self._debounce_timer = None
        self._pending_changes = set()
        self.desktop_dir = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DESKTOP)
        if not self.desktop_dir:
            self.desktop_dir = os.path.join(GLib.get_home_dir(), "Desktop")
            
        self.gfile = Gio.File.new_for_path(self.desktop_dir)
        
        self.load_initial_files()
        self.monitor = self.gfile.monitor_directory(Gio.FileMonitorFlags.NONE, None)
        self.monitor.connect("changed", self.on_file_changed)

    def load_initial_files(self):
        if not os.path.exists(self.desktop_dir):
            return
            
        enumerator = self.gfile.enumerate_children(
            "standard::*,thumbnail::path", Gio.FileQueryInfoFlags.NONE, None
        )
        
        for info in enumerator:
            if not SHOW_HIDDEN and info.get_name().startswith('.'):
                continue
            filepath = os.path.join(self.desktop_dir, info.get_name())
            for layout in self.layouts:
                layout.add_icon(filepath, info)
                
        def add_special(uri, name, icon_name, target_uri):
            info = Gio.FileInfo.new()
            info.set_display_name(name)
            info.set_icon(Gio.ThemedIcon.new_from_names([icon_name]))
            info.set_file_type(Gio.FileType.SHORTCUT)
            info.set_attribute_string("standard::target-uri", target_uri)
            for layout in self.layouts:
                layout.add_icon(uri, info)
                
        if SHOW_HOME:
            add_special("virtual://home", "Home", "user-home", f"file://{GLib.get_home_dir()}")
        if SHOW_TRASH:
            icon_name = "user-trash"
            try:
                trash_file = Gio.File.new_for_uri("trash:///")
                trash_info = trash_file.query_info("trash::item-count", Gio.FileQueryInfoFlags.NONE, None)
                if trash_info and trash_info.get_attribute_uint32("trash::item-count") > 0:
                    icon_name = "user-trash-full"
            except Exception:
                pass
            add_special("virtual://trash", "Trash", icon_name, "trash:///")
        if SHOW_COMPUTER:
            add_special("virtual://computer", "This PC", "computer-symbolic", "computer:///")

    def on_file_changed(self, monitor, file, other_file, event_type):
        filepath = file.get_path()
        if not filepath:
            return
        filename = os.path.basename(filepath)
        
        if not SHOW_HIDDEN and filename.startswith('.'):
            return

        self._pending_changes.add((filepath, event_type))
        if self._debounce_timer:
            GLib.source_remove(self._debounce_timer)
        self._debounce_timer = GLib.timeout_add(150, self._process_file_changes)

    def _process_file_changes(self):
        self._debounce_timer = None
        for filepath, event_type in self._pending_changes:
            if event_type in (Gio.FileMonitorEvent.CREATED, Gio.FileMonitorEvent.CHANGES_DONE_HINT):
                try:
                    file = Gio.File.new_for_path(filepath)
                    info = file.query_info("standard::*,thumbnail::path", Gio.FileQueryInfoFlags.NONE, None)
                    if info:
                        for layout in self.layouts:
                            if filepath in layout.icons:
                                layout.remove_icon(filepath)
                            layout.add_icon(filepath, info)
                except Exception:
                    pass
            elif event_type == Gio.FileMonitorEvent.DELETED:
                for layout in self.layouts:
                    layout.remove_icon(filepath)
        self._pending_changes.clear()
        return False


################################################################################
# GLOBAL DRAG & DROP HANDLERS
# Functions to handle data dropped directly onto the main window/grid.
################################################################################

def on_drag_data_received(widget, drag_context, x, y, data, info, time):
    if hasattr(widget, 'layout_container'):
        widget.layout_container.clear_drop_target()
    
    uris = data.get_uris()
    if not uris:
        Gtk.drag_finish(drag_context, False, False, time)
        return
        
    desktop_dir = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DESKTOP)
    if not desktop_dir:
        desktop_dir = os.path.join(GLib.get_home_dir(), "Desktop")
    desktop_file = Gio.File.new_for_path(desktop_dir)

    multi_paths = getattr(widget, '_multi_drag_paths', None)
    multi_origin = getattr(widget, '_multi_drag_origin', None)
    widget._multi_drag_paths = None
    widget._multi_drag_origin = None

    if multi_paths and multi_origin:
        widget._internal_drop_handled = True
        positions = load_positions()
        origin_filename = os.path.basename(multi_origin)
        origin_pos = positions.get(origin_filename, {'col': 0, 'row': 0})
        base_col, base_row = get_grid_pos(x, y)

        for path in multi_paths:
            filename = os.path.basename(path)
            pos = positions.get(filename, origin_pos)
            delta_col = pos.get('col', 0) - origin_pos.get('col', 0)
            delta_row = pos.get('row', 0) - origin_pos.get('row', 0)
            positions[filename] = {
                'col': max(0, base_col + delta_col),
                'row': max(0, base_row + delta_row),
            }

        save_positions(positions)
        if hasattr(widget, 'layout_container'):
            widget.layout_container.reposition_icons()
        Gtk.drag_finish(drag_context, True, False, time)
        return

    success = False
    for uri in uris:
        if not uri.startswith("file://"):
            continue
            
        source_path = urllib.parse.unquote(uri[7:])
        source_file = Gio.File.new_for_path(source_path)
        
        if source_file.get_parent() and source_file.get_parent().get_path() == desktop_file.get_path():
            widget._internal_drop_handled = True
            filename = source_file.get_basename()
            positions = load_positions()
            
            col, row = get_grid_pos(x, y)
            positions[filename] = {'col': col, 'row': row}
            save_positions(positions)
            
            if hasattr(widget, 'layout_container'):
                widget.layout_container.reposition_icons()
                
            success = True
            continue 
            
        dest_path = os.path.join(desktop_dir, os.path.basename(source_path))
        
        if os.path.exists(dest_path) or os.path.islink(dest_path):
            print(f"Skipped: {dest_path} already exists")
            continue

        is_folder = os.path.isdir(source_path)
        action_key = 'drop_in_folder' if is_folder else 'drop_in_file'
        mode = ACTION_MODES.get(action_key, DEFAULT_ACTIONS[action_key])

        ok = apply_drop_in_action(mode, source_path, dest_path)
        if ok:
            print(f"[{action_key}={mode}] {source_path} -> {dest_path}")

            col, row = get_grid_pos(x, y)
            filename = os.path.basename(dest_path)
            positions = load_positions()
            positions[filename] = {'col': col, 'row': row}
            save_positions(positions)

            success = True
        elif mode == 'none':
            print(f"Skipped ({action_key}=none): {source_path}")
        else:
            print(f"Failed to apply '{mode}' for {action_key} on: {source_path}")

    Gtk.drag_finish(drag_context, success, False, time)

def on_drag_motion(widget, drag_context, x, y, time):
    if hasattr(widget, 'layout_container'):
        layout = widget.layout_container
        col, row = get_grid_pos(x, y)
        col = min(col, layout.cols - 1)
        row = min(row, layout.rows - 1)
        layout.set_drop_target(col, row)
    return False

def on_drag_leave(widget, drag_context, time):
    if hasattr(widget, 'layout_container'):
        widget.layout_container.clear_drop_target()


################################################################################
# APPLICATION INITIALIZATION
# Setup windows for all monitors and start the main GTK application.
################################################################################

def create_desktop_window(app, monitor):
    window = Gtk.ApplicationWindow(application=app)
    window.set_title("desktop-icons")
    window.set_wmclass("desktop-icons", "desktop-icons")
    
    GtkLayerShell.init_for_window(window)
    GtkLayerShell.set_namespace(window, "desktop-icons")
    GtkLayerShell.set_monitor(window, monitor)
    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.BACKGROUND)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.BOTTOM, True)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.LEFT, True)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.RIGHT, True)
    
    try:
        GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.ON_DEMAND)
    except AttributeError:
        GtkLayerShell.set_keyboard_interactivity(window, True)

    screen = window.get_screen()
    visual = screen.get_rgba_visual()
    if visual and screen.is_composited():
        window.set_visual(visual)
    
    css_provider_window = Gtk.CssProvider()
    css_provider_window.load_from_data(b"window { background-color: rgba(0, 0, 0, 0); }")
    context = window.get_style_context()
    context.add_provider(css_provider_window, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    window.drag_dest_set(Gtk.DestDefaults.MOTION | Gtk.DestDefaults.DROP, [], Gdk.DragAction.COPY | Gdk.DragAction.MOVE)
    window.drag_dest_add_uri_targets()
    window.connect("drag-data-received", on_drag_data_received)
    window.connect("drag-motion", on_drag_motion)
    window.connect("drag-leave", on_drag_leave)

    layout = DesktopLayout(window)
    window.layout_container = layout
    window.add(layout)
    window.connect("key-press-event", layout.on_key_press)
    
    app.layouts.append(layout)
    
    window.show_all()

def on_activate(app):
    app.layouts = []
    
    if not os.path.exists(CSS_FILE):
        old_css_file = os.path.join(CONFIG_DIR, "style.css")
        if os.path.exists(old_css_file):
            try:
                os.rename(old_css_file, CSS_FILE)
            except Exception:
                pass
    if not os.path.exists(CSS_FILE):
        try:
            with open(CSS_FILE, 'w') as f:
                f.write(DEFAULT_CSS.strip())
        except Exception:
            pass

    css_provider = Gtk.CssProvider()
    try:
        css_provider.load_from_path(CSS_FILE)
    except Exception:
        css_provider.load_from_data(DEFAULT_CSS.encode('utf-8'))

    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        css_provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )
    
    display = Gdk.Display.get_default()
    
    n_monitors = display.get_n_monitors()
    for i in range(n_monitors):
        monitor = display.get_monitor(i)
        create_desktop_window(app, monitor)

    app.manager = DesktopManager(app.layouts)

if __name__ == '__main__':
    GLib.set_prgname('desktop-icons')
    app = Gtk.Application(application_id='org.desktop_icons.desktop')
    app.connect('activate', on_activate)
    status = app.run(sys.argv)
    sys.exit(status)