#!/usr/bin/env python3
"""Check desktop canvas transparency and inheritance of the selected GTK menu theme."""
import ast
from pathlib import Path
import unittest
from unittest.mock import MagicMock
import cairo
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk

SOURCE = Path(__file__).resolve().parents[3] / 'src/core/app/desktop-icons/desktop_icons.py'

class DesktopStyleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not Gtk.init_check()[0]:
            raise unittest.SkipTest('GTK display required (Broadway is sufficient)')
        # Importing the whole app would upgrade the real desktop configuration.
        tree = ast.parse(SOURCE.read_text())
        selected = [node for node in tree.body if (isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'DEFAULT_CSS' for t in node.targets)) or (isinstance(node, ast.FunctionDef) and node.name == 'create_desktop_window')]
        class Layout(Gtk.Fixed):
            def on_key_press(self, *args): return False
            def __init__(self, window): super().__init__()
        cls.namespace = dict(Gtk=Gtk, Gdk=Gdk, GtkLayerShell=MagicMock(), cairo=cairo, DesktopLayout=Layout,
                             on_drag_data_received=lambda *args: None, on_drag_motion=lambda *args: False, on_drag_leave=lambda *args: None)
        cls.namespace['GtkLayerShell'].init_for_window.side_effect = lambda window: window.set_decorated(False)
        exec(compile(ast.Module(body=selected, type_ignores=[]), str(SOURCE), 'exec'), cls.namespace)

    def test_application_css_preserves_menu_theme(self):
        baseline = Gtk.Menu()
        base_item = Gtk.MenuItem(label='Baseline')
        baseline.append(base_item)
        menu = Gtk.Menu()
        menu.get_style_context().add_class('desktop-context-menu')
        item = Gtk.MenuItem(label='Themed')
        menu.append(item)
        provider = Gtk.CssProvider()
        errors = []
        provider.connect('parsing-error', lambda p, s, e: errors.append(str(e)))
        provider.load_from_data(self.namespace['DEFAULT_CSS'].encode())
        screen = Gdk.Screen.get_default()
        Gtk.StyleContext.add_provider_for_screen(screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        try:
            self.assertEqual(errors, [])
            for actual, expected in ((menu, baseline), (item, base_item)):
                for state in (Gtk.StateFlags.NORMAL, Gtk.StateFlags.PRELIGHT):
                    values = []
                    for widget in (actual, expected):
                        context = widget.get_style_context()
                        context.save()
                        context.set_state(state)
                        values.append((context.get_background_color(state).to_string(), context.get_color(state).to_string()))
                        context.restore()
                    self.assertEqual(*values)
        finally:
            Gtk.StyleContext.remove_provider_for_screen(screen, provider)
            baseline.destroy()
            menu.destroy()

    def test_canvas_renders_transparent(self):
        app = Gtk.Application(flags=0)
        app.register(None)
        app.layouts = []
        self.namespace['create_desktop_window'](app, None)
        windows = app.get_windows()
        self.assertEqual(len(windows), 1)
        window = windows[0]
        window.resize(320, 240)
        while Gtk.events_pending(): Gtk.main_iteration_do(False)
        surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, window.get_allocated_width(), window.get_allocated_height())
        window.draw(cairo.Context(surface))
        surface.flush()
        pixels = bytes(surface.get_data())
        self.assertTrue(all(alpha == 0 for alpha in pixels[3::4]), 'Desktop canvas must not paint an opaque background')
        window.destroy()
        app.quit()

if __name__ == '__main__':
    unittest.main()
