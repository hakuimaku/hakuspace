from colorthief import ColorThief
import sys

def brightness(c):
    return sum(v*v for v in c)

colors = ColorThief(sys.argv[1]).get_palette(color_count=5)
brightest = max(colors,key=brightness)

print("#%02x%02x%02x" % brightest)