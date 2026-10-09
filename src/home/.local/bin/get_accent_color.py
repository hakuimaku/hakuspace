from colorthief import ColorThief
import colorsys
import argparse
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
    if mode == "brightest":
        return max(colors, key=brightness)
    if mode == "dominant":
        return colors[0]
    if mode == "saturated":
        return max(colors, key=saturation)
    if mode == "vivid":
        vivid_colors = [color for color in colors if saturation(color) >= MIN_SATURATION]
        return max(vivid_colors or colors, key=score)
    raise ValueError(f"Unknown accent color mode: {mode}")

parser = argparse.ArgumentParser(
    description="Extract an accent color from an image."
)
parser.add_argument("image", help="Path to the image file")
parser.add_argument(
    "mode", nargs="?", default="vivid",
    choices=("vivid", "dominant", "brightest", "saturated"),
    help="Color selection mode (default: vivid)",
)
args = parser.parse_args()

colors = ColorThief(args.image).get_palette(color_count=5)
mode = args.mode
accent = choose_color(colors, mode)

print("#%02x%02x%02x" % accent)