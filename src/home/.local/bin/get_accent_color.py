from colorthief import ColorThief
import colorsys
import sys

MIN_SATURATION = 0.2

def brightness(c):
    return sum(v*v for v in c)

def saturation(c):
    red, green, blue = (value / 255 for value in c)
    return colorsys.rgb_to_hsv(red, green, blue)[1]

def score(c):
    return brightness(c) * (0.5 + saturation(c))

def choose_color(colors, mode):
    if mode in ("legacy", "brightest"):
        return max(colors, key=brightness)
    if mode == "dominant":
        return colors[0]
    if mode == "saturated":
        return max(colors, key=saturation)
    if mode == "vivid":
        vivid_colors = [color for color in colors if saturation(color) >= MIN_SATURATION]
        return max(vivid_colors or colors, key=score)
    raise ValueError(f"Unknown accent color mode: {mode}")

colors = ColorThief(sys.argv[1]).get_palette(color_count=5)
mode = sys.argv[2] if len(sys.argv) > 2 else "vivid"
accent = choose_color(colors, mode)

print("#%02x%02x%02x" % accent)