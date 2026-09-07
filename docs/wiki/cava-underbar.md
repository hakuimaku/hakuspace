# Cava Underbar

Cava Underbar is a standalone audio visualizer displayed as a transparent bar along the top of the screen. It runs independently from Waybar and does not reserve screen space, so normal windows can still use the full screen.

## Using Cava Underbar

Toggle it with `SUPER + T`, or choose `Haku Menu > Theme > Cava Underbar`.

The SwayNC quick-settings panel also has a Cava toggle. Use it when you want to start or stop the visualizer without opening Haku Menu.

The feature starts automatically with the default configuration when no custom arguments are provided. The process and log are managed using:

- PID file: `/tmp/cava-layer.pid`
- Log file: `/tmp/cava-layer.log`

## Customizing the Cava visualizer

The default Cava configuration is `~/.config/cava/cava-layer`. Edit this file to customize the visualizer using normal Cava settings.

Common options include:

```ini
[general]
bar_width = 6
bar_spacing = 1

[output]
method = ncurses
orientation = top

[color]
foreground = black
```

- `bar_width`: width of each bar.
- `bar_spacing`: gap between bars.
- `orientation`: direction of the bars.
- `foreground`: bar color.

If `~/.config/cava/cava-layer` does not exist, HakuSpace creates it with the default values on the first start.

## Changing height and font size

`cava_manager.sh` forwards these options to the layer window:

```bash
~/.local/bin/cava_manager.sh stop
~/.local/bin/cava_manager.sh start --height 80 --font-size 5
```

- `--height`: layer height in pixels. The default is `80`.
- `--font-size`: terminal font size used to render the bars. The default is `5`.
- `--config PATH`: use another Cava configuration file.
- `--app-name NAME`: set the layer namespace and window class.

For example, to test another configuration without replacing the default one:

```bash
~/.local/bin/cava_manager.sh start --config ~/.config/cava/my-cava-config
```

## Dependencies

Cava Underbar requires:

- `python3`;
- `cava`;
- Python GObject (`python3-gi` or PyGObject);
- GTK Layer Shell bindings;
- VTE 2.91 bindings.

On Arch Linux, the required packages are:

```bash
sudo pacman -S cava python-gobject gtk-layer-shell vte3
```

Audio must be available through the system audio stack for Cava to show activity.

## Troubleshooting

If the toggle does nothing, check the log:

```bash
cat /tmp/cava-layer.log
```

If the log says that `cava` is missing, install Cava and check that it is available with `which cava`. If a Python, GTK Layer Shell, or VTE dependency is missing, install the corresponding package and toggle the feature again.

If the bar is visible but empty, check the Cava input and audio output configuration in `~/.config/cava/cava-layer`, then play audio and restart the feature.