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

colors = ColorThief(sys.argv[1]).get_palette(color_count=5)
vivid_colors = [color for color in colors if saturation(color) >= MIN_SATURATION]
brightest = max(vivid_colors or colors, key=score)

print("#%02x%02x%02x" % brightest)