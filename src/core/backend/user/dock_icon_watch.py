#!/usr/bin/env python3
"""Stream fresh Dock icon file URLs when GTK themes or displayed files change."""
import configparser
import json
import os
from pathlib import Path
import sys

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gio, GLib, Gtk


class IconWatcher:
    # Share one native theme index and file-monitor set across every Dock output.
    def __init__(self):
        self.icons = []
        self.size = 48
        self.pending = 0
        self.monitors = {}
        self.input_buffer = b''
        self.config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config') / 'gtk-3.0/settings.ini'
        source = Gio.SettingsSchemaSource.get_default()
        schema = source.lookup('org.gnome.desktop.interface', True) if source else None
        self.settings = Gio.Settings.new_full(schema, None, None) if schema else None
        if self.settings:
            self.settings.connect('changed::icon-theme', self.settings_changed)
        Gtk.init_check()
        gtk_settings = Gtk.Settings.get_default()
        self.theme_name = gtk_settings.get_property('gtk-icon-theme-name') if gtk_settings else self.config_theme()
        os.set_blocking(sys.stdin.fileno(), False)
        GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, self.read_request)

    # Honor the same GTK theme file used by the shell's GTK platform integration.
    def config_theme(self):
        config = configparser.ConfigParser(interpolation=None)
        try:
            config.read(self.config)
            name = config.get('Settings', 'gtk-icon-theme-name', fallback='').strip().strip('"\'')
            if name:
                return name
        except (configparser.Error, OSError):
            pass
        return self.settings.get_string('icon-theme') if self.settings else 'Adwaita'

    # Desktop theme changes take effect without restarting the image consumer.
    def settings_changed(self, settings, key):
        self.theme_name = settings.get_string(key)
        self.schedule()

    # Coalesce editor replacements and batches of regenerated icon assets.
    def schedule(self, *args):
        if not self.pending:
            self.pending = GLib.timeout_add(120, self.publish)

    # Watch both a symlink and its target, including atomic file replacement.
    def watch(self, paths):
        for path in self.monitors.keys() - paths.keys():
            self.monitors.pop(path).cancel()
        for path in paths.keys() - self.monitors.keys():
            try:
                file = Gio.File.new_for_path(path)
                monitor = (file.monitor_directory if paths[path] else file.monitor_file)(Gio.FileMonitorFlags.NONE, None)
                monitor.connect('changed', self.file_changed)
                self.monitors[path] = monitor
            except GLib.Error:
                continue

    # Reload theme configuration before resolving another batch of file URLs.
    def file_changed(self, monitor, file, other, event):
        if file.get_path() in (str(self.config), str(self.config.resolve())):
            self.theme_name = self.config_theme()
        self.schedule()

    # Monitor the active theme, its inherited directories and roots for newly added icons.
    def theme_paths(self, theme):
        paths = {str(self.config): False, str(self.config.resolve()): False}
        pending = [self.theme_name, 'hicolor']
        visited = set()
        for root in theme.get_search_path():
            parent = Path(root)
            while not parent.is_dir() and parent != parent.parent:
                parent = parent.parent
            paths[str(parent)] = True
        while pending:
            name = pending.pop()
            if name in visited:
                continue
            visited.add(name)
            for root in theme.get_search_path():
                directory = Path(root) / name
                if not directory.is_dir():
                    continue
                paths[str(directory)] = True
                index = directory / 'index.theme'
                paths[str(index)] = False
                config = configparser.ConfigParser(interpolation=None, strict=False)
                try:
                    config.read(index)
                    pending.extend(name.strip() for name in config.get('Icon Theme', 'Inherits', fallback='').split(',') if name.strip())
                    for key in ('Directories', 'ScaledDirectories'):
                        for folder in config.get('Icon Theme', key, fallback='').split(','):
                            if folder.strip():
                                paths[str(directory / folder.strip())] = True
                except (configparser.Error, OSError):
                    continue
        return paths

    # File versions invalidate Qt image decoding without changing the application model.
    def publish(self):
        self.pending = 0
        theme = Gtk.IconTheme.new()
        theme.set_custom_theme(self.theme_name)
        sources = {}
        paths = self.theme_paths(theme)
        for name in self.icons:
            info = None if os.path.isabs(name) else theme.lookup_icon(name, self.size, Gtk.IconLookupFlags.FORCE_SIZE)
            filename = name if os.path.isabs(name) else info.get_filename() if info else None
            if not filename:
                continue
            path = Path(filename)
            paths.update({str(path): False, str(path.resolve()): False})
            try:
                stat = path.stat()
                sources[name] = path.as_uri() + '?v=' + str(stat.st_mtime_ns) + '-' + str(stat.st_ctime_ns)
            except OSError:
                continue
        self.watch(paths)
        print(json.dumps(sources), flush=True)
        return GLib.SOURCE_REMOVE

    # Receive only the icon names currently represented in the shared Dock model.
    def read_request(self, stream, condition):
        chunk = os.read(stream.fileno(), 65536)
        if not chunk:
            loop.quit()
            return GLib.SOURCE_REMOVE
        self.input_buffer += chunk
        while b'\n' in self.input_buffer:
            line, self.input_buffer = self.input_buffer.split(b'\n', 1)
            self.accept_request(line)
        return GLib.SOURCE_CONTINUE

    # Validate a complete request before replacing the active icon set.
    def accept_request(self, line):
        try:
            request = json.loads(line)
            icons, size = request['icons'], request['size']
            if not isinstance(icons, list) or any(not isinstance(icon, str) or '\0' in icon for icon in icons):
                raise ValueError('Invalid icon names')
            if type(size) is not int or not 1 <= size <= 512:
                raise ValueError('Invalid icon size')
            self.icons = list(dict.fromkeys(icon for icon in icons if icon))
            self.size = size
            self.schedule()
        except (ValueError, KeyError, TypeError) as error:
            print('Dock icon request: ' + str(error), file=sys.stderr, flush=True)


if __name__ == '__main__':
    loop = GLib.MainLoop()
    watcher = IconWatcher()
    loop.run()
