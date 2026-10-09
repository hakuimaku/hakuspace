# Troubleshooting

## A feature does not respond

1. Try the action again from Haku Menu.
2. Check that the related application is installed.
3. Run the related script in a terminal to see the error message.
4. Log out and back in if the issue involves Waybar, themes, or wallpapers.

## Cava is not displayed

Install `cava` and the Cava Underbar dependencies, then check that audio is playing. See [Cava Underbar](cava-underbar.md) for the complete dependency list and log location.

## Screen recording does not start

Check `wl-screenrec`, `pactl`, and PipeWire/PulseAudio access. Try `No Sound` to distinguish a video-capture problem from an audio problem.

## The wallpaper or accent color does not change

Make sure images are in `~/Pictures/Wallpapers` and videos are in `~/Videos/Wallpapers`, then choose one again from the menu. Avoid unusual characters in filenames.

## SwayNC starts automatically and causes issues on Fedora

If SwayNC starts at the same time as HakuSpace, disable the user service with:

```bash
systemctl --user disable swaync.service
```

## Still not resolved

Check the package lists in `src/packages/`, read the error directly in a terminal, then open a GitHub issue including your window manager, distribution, and error message.
