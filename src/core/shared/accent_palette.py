#!/usr/bin/env python3
"""Derive matching accents with readable contrast on every Hikai surface."""

import colorsys
import json
import re
import sys


def luminance(color):
    """Return WCAG relative luminance for a six-digit sRGB color."""
    channels = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
              for value in channels]
    return sum(value * weight for value, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    """Compare two opaque colors using the WCAG contrast ratio."""
    bright, dark = sorted((luminance(first), luminance(second)), reverse=True)
    return (bright + 0.05) / (dark + 0.05)


def derive(seed):
    """Preserve seed hue and saturation, adjusting only the required lightness."""
    seed = seed.lower() if re.fullmatch(r"#[0-9a-fA-F]{6}", seed) else "#ffffff"
    hue, lightness, saturation = colorsys.rgb_to_hls(
        *(int(seed[index:index + 2], 16) / 255 for index in (1, 3, 5)))

    def variant(surface, endpoint, minimum):
        """Find the closest passing lightness, including quantized RGB contrast."""
        if contrast(seed, surface) >= minimum:
            return seed
        failing, passing = lightness, endpoint
        result = "#ffffff" if endpoint else "#000000"
        for _ in range(24):
            candidate = (failing + passing) / 2
            color = "#%02x%02x%02x" % tuple(
                round(value * 255) for value in colorsys.hls_to_rgb(hue, candidate, saturation))
            if contrast(color, surface) >= minimum:
                passing, result = candidate, color
            else:
                failing = candidate
        return result

    # The least contrasting surfaces also protect the other two tones in each mode.
    return {"seed": seed, "dark": variant("#171717", 1, 4.5), "light": variant("#d6d6d6", 0, 7)}


if __name__ == "__main__":
    print(json.dumps(derive(sys.argv[1] if len(sys.argv) == 2 else "")))
