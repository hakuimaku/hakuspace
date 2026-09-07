# Dockbar

Dockbar is an optional application bar similar to a taskbar or dock.

## Toggling Dockbar

Press `SUPER + W`, or choose `Haku Menu > Theme > Toggle Dockbar`.

## Auto-hide and exclusive mode

In `Haku Menu > Setting`:

- `Dockbar Auto-hide`: Dockbar hides itself and reappears when the pointer reaches the screen edge.
- `Dockbar Exclusive`: reserves screen space for Dockbar so windows do not cover it.

## Changing icon size

Choose `Haku Menu > Setting > Dockbar Icon Size`, enter the desired size, and confirm.

## Pinning applications

The pinned application list is in `~/hakucfg/config/dockbar_pin_apps`. After changing the list, turn Dockbar off and on again to apply it.

## Customizing Dockbar

Edit `~/hakucfg/config/dockbar_pin_apps` to change the pinned icons. Each application needs:

- an entry in the `modules` list inside `group/pin`;
- an `image#name` module with an icon command and an `on-click` command.

For example:

```jsonc
"image#myapp": {
	"exec": "$HOME/.local/bin/dockbar_geticon.sh myapp",
	"size": 40,
	"interval": "once",
	"on-click": "myapp"
}
```

Replace `myapp` with the application command. Add `"image#myapp"` to the `modules` list so the icon appears.

To change Dockbar layout, position, spacing, or behavior, edit the deployed Waybar Dockbar configuration at `~/.config/waybar/dockbar/config`. Common options include:

- `position`: `top`, `bottom`, `left`, or `right`;
- `exclusive`: whether Dockbar reserves screen space;
- `icon-size`: the size of running-application icons;
- `on-click`, `on-click-middle`, and `on-click-right` in `wlr/taskbar`.

To change colors, padding, hover effects, or animations, edit `~/.config/waybar/dockbar/style.css`. These files are generated from HakuSpace defaults, so keep personal changes in the deployed files only if you understand that an update may replace them.

