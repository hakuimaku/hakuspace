#!/usr/bin/env python3
"""Validate geometry traces captured by the native Leftbar harness."""
import json
import sys
from pathlib import Path


def monotonic(values, opening, tolerance=0.5):
    """Allow subpixel settling while rejecting motion on the wrong reveal path."""
    direction = 1 if opening else -1
    return all(direction * (after - before) >= -tolerance for before, after in zip(values, values[1:]))


def check(directory):
    """Check frame coverage, physical-axis motion and notification attachment."""
    traces = sorted(directory.glob("*-open.json")) + sorted(directory.glob("*-close.json"))
    assert any(path.name == "notifications-open.json" for path in traces), "missing notification opening trace"
    assert any(path.name == "notifications-close.json" for path in traces), "missing notification closing trace"
    for path in traces:
        trace = json.loads(path.read_text())
        samples = trace["samples"]
        opening = path.stem.endswith("-open")
        assert trace["frames"] >= 10, f"{path.name}: insufficient composited frames"
        assert len(samples) >= 10, f"{path.name}: insufficient geometry samples"
        motion = samples
        if path.stem == "navigation-close":
            # The closed controller resets its next-open depth to the logo footprint.
            zero = next((index for index, sample in enumerate(samples) if sample["depth"] < 0.5), len(samples) - 1)
            motion = samples[:zero + 1]
        tolerance = 0.001 if path.stem.startswith("wallpaper") else 0.5
        assert monotonic([sample["depth"] for sample in motion], opening, tolerance), f"{path.name}: reveal reversed direction"
        if path.stem.startswith("navigation"):
            visible = [sample for sample in samples if sample["depth"] > 1]
            assert len(visible) >= 4, f"{path.name}: insufficient visible main-flare frames"
            assert all(sample["leftAttached"] for sample in visible), f"{path.name}: main flare still top-attached"
            for key in ("x", "y", "span"):
                assert max(sample[key] for sample in visible) - min(sample[key] for sample in visible) < 0.5, f"{path.name}: moving {key} on left reveal"
            assert all(sample["titleOpacity"] == 1 and sample["titleEnabled"] and sample["workspaceOpacity"] == 0 and not sample["workspaceEnabled"] for sample in visible), f"{path.name}: Navigation hides more than the logo/workspace group or leaves workspaces interactive"
            assert monotonic([sample["x"] + sample["depth"] for sample in visible], opening), f"{path.name}: physical right edge reversed"
        if path.stem.startswith("notifications"):
            visible = [sample for sample in samples if sample["depth"] > 1]
            assert len(visible) >= 5, f"{path.name}: no visible transition"
            for key in ("x", "y", "span", "contentX", "contentY"):
                values = [sample[key] for sample in visible]
                assert max(values) - min(values) < 0.5, f"{path.name}: moving {key}"
            assert all(sample["openedAtLeft"] for sample in visible), f"{path.name}: wrong attachment"
            assert all(sample["y"] + sample["span"] <= sample["usableBottom"] + 0.5 for sample in visible), f"{path.name}: overlaps Dock reservation"
            assert all(zone["y"] + zone["height"] <= sample["usableBottom"] + 0.5
                       for sample in visible for zone in sample["zones"]), f"{path.name}: input mask covers Dock"
            assert monotonic([sample["x"] + sample["depth"] for sample in visible], opening), f"{path.name}: right edge moved backwards"
        if path.stem.startswith("wallpaper"):
            # Cold-load and teardown coordinates at zero reveal are outside visible motion.
            visible = [sample for sample in samples if sample["depth"] > 0.001
                       and sample["infoSlide"] is not None and sample["gallerySlide"] is not None]
            assert len(visible) >= 4, f"{path.name}: insufficient visible wallpaper samples"
            assert monotonic([sample["infoSlide"] for sample in visible], opening), f"{path.name}: left info path reversed"
            assert monotonic([sample["gallerySlide"] for sample in visible], not opening), f"{path.name}: right gallery path reversed"
        print(f"PASS {path.name}: {trace['frames']} native frames, {len(samples)} geometry samples")


if __name__ == "__main__":
    check(Path(sys.argv[1]))
