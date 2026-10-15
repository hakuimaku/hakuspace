#!/usr/bin/env python3
"""Convert discovered desktop entries to native picker metadata."""

import configparser
import json
from pathlib import Path
import sys


# Read the same paths discovered by shortcut_ctl.sh.
def main():
    entries = []
    for line in sys.stdin:
        path = Path(line.rstrip("\n"))
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            parser.read(path, encoding="utf-8")
            desktop = parser["Desktop Entry"]
            if desktop.get("Hidden", "false").lower() == "true" or desktop.get("NoDisplay", "false").lower() == "true":
                continue
            name = desktop.get("Name", path.stem).strip()
            if name:
                entries.append({"name": name, "path": str(path),
                                "categories": desktop.get("Categories", ""),
                                "icon": desktop.get("Icon", "").strip() or "application-x-executable"})
        except (OSError, UnicodeError, configparser.Error, KeyError):
            continue
    print(json.dumps(sorted(entries, key=lambda item: item["name"].casefold()), ensure_ascii=False))


if __name__ == "__main__":
    main()
