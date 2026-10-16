#!/usr/bin/env python3
"""HakuSpace: safely edit embedded KDE highlight colors in user icon themes."""
import argparse
import contextlib
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from xml.parsers import expat


class AccentError(Exception):
    def __init__(self, message, code=1):
        super().__init__(message)
        self.code = code


def inside(path, root):
    return path == root or root in path.parents


def digest(data):
    return hashlib.sha256(data).hexdigest()


def normalize_color(value):
    if not re.fullmatch(r"#?[0-9a-fA-F]{6}", value):
        raise argparse.ArgumentTypeError("color must be six hexadecimal digits, optionally prefixed with #")
    return "#" + value.lstrip("#").lower()


def validate_svg(data):
    # DTDs/entities are unnecessary for icon recoloring and complicate safe parsing.
    if re.search(br"<!\s*(?:DOCTYPE|ENTITY)\b", data, re.I):
        raise ValueError("DTD/entity declarations are not supported")
    root = ET.fromstring(data)
    if root.tag not in ("svg", "{http://www.w3.org/2000/svg}svg"):
        raise ValueError("document is not an SVG")
    return root


def style_spans(data):
    """Use XML byte offsets so comments, attributes and unrelated XML stay intact."""
    parser = expat.ParserCreate(namespace_separator="}")
    active = None
    spans = []

    def start(name, attrs):
        nonlocal active
        if name in ("style", "http://www.w3.org/2000/svg}style") and attrs.get("id") == "current-color-scheme":
            offset = parser.CurrentByteIndex
            tag = re.match(br'''<[^\s>]+(?:[^>"']|"[^"]*"|'[^']*')*>''', data[offset:])
            if tag and not tag[0].endswith(b"/>"):
                active = offset + tag.end()

    def end(name):
        nonlocal active
        if name in ("style", "http://www.w3.org/2000/svg}style") and active is not None:
            spans.append((active, parser.CurrentByteIndex))
            active = None

    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.Parse(data, True)
    return spans


class KDEColorSchemeBackend:
    @staticmethod
    def detect(data, root):
        users = 0

        def visit(node, highlighted=False):
            nonlocal users
            highlighted = highlighted or "ColorScheme-Highlight" in node.get("class", "").split()
            styles = dict(re.findall(r"(?:^|;)\s*([\w-]+)\s*:\s*([^;]+)", node.get("style", "")))
            if highlighted and any(styles.get(prop, node.get(prop, "")).strip().lower() == "currentcolor" for prop in ("fill", "stroke")):
                users += 1
            for child in node:
                visit(child, highlighted)

        visit(root)
        edits = []
        if not users:
            return edits, users
        for start, end in style_spans(data):
            css = data[start:end]
            # Mask comments/CDATA delimiters without shifting the original byte offsets.
            css = re.sub(br"/\*.*?\*/|<!--.*?-->|<!\[CDATA\[|\]\]>", lambda m: b" " * len(m[0]), css, flags=re.S)
            # shortcut: only flat CSS rules are editable; add a CSS parser for nested syntax.
            rules = list(re.finditer(br"([^{}]*)\{([^{}]*)\}", css))
            if re.sub(br"[^{}]*\{[^{}]*\}", b"", css).strip():
                continue
            for rule in rules:
                if rule[1].strip() != b".ColorScheme-Highlight":
                    continue
                for color in re.finditer(br"(?:^|;)\s*color\s*:\s*(#[0-9a-fA-F]{6})(?:\s*!important)?\s*(?=;|$)", rule[2], re.I):
                    a = start + rule.start(2) + color.start(1)
                    edits.append((a, a + 7, color[1].decode().lower()))
        return edits, users

    @staticmethod
    def patch(data, edits, color):
        for start, end, _ in reversed(edits):
            data = data[:start] + color.encode() + data[end:]
        validate_svg(data)
        return data


class GTKSymbolicBackend:
    @staticmethod
    def detect(path, root, data):
        namespaces = {uri for _, (prefix, uri) in ET.iterparse(io.BytesIO(data), events=("start-ns",)) if prefix == "gpa"}
        namespaces.add("http://www.gtk.org/grappa")
        symbolic = path.name.endswith("-symbolic.svg") or "symbolic" in path.parts
        gpa = any(key.startswith("{") and key[1:].split("}")[0] in namespaces and value == "accent"
                  for node in root.iter() for key, value in node.attrib.items())
        return symbolic, gpa


class ThemeScanner:
    def __init__(self, icons_dir):
        self.root = Path(icons_dir).expanduser().resolve()
        for system_root in (Path("/usr/share/icons"), Path("/usr/local/share/icons")):
            if inside(self.root, system_root):
                raise AccentError("system-wide icon directories are not supported", 2)

    def theme(self, name):
        if not name or name in (".", "..") or Path(name).name != name:
            raise AccentError("theme must be a directory name", 2)
        path = self.root / name
        try:
            resolved = path.resolve()
        except (OSError, RuntimeError) as exc:
            raise AccentError(f"theme not found: {name}: {exc}", 3) from exc
        if not inside(resolved, self.root) or resolved == self.root or not (path / "index.theme").is_file():
            raise AccentError(f"theme not found: {name}", 3)
        if not inside((path / "index.theme").resolve(), resolved):
            raise AccentError(f"index.theme points outside theme: {name}", 3)
        return resolved

    def themes(self):
        if not self.root.exists():
            return []
        result = []
        for path in sorted(self.root.iterdir()):
            try:
                self.theme(path.name)
            except AccentError:
                continue
            result.append(path.name)
        return result

    def scan(self, name):
        theme = self.theme(name)
        report = dict(theme=name, location=str(theme), svg_files=0, unique_svg_files=0,
                      kde_matched=0, highlight_users=0, gtk_symbolic=0, gtk_gpa_accent=0,
                      static_svg=0, skipped_symlinks=0, invalid_svg=[], folder_variants=[],
                      accents=[], editable_accents=[], editable_svg_files=0, backend="static-svg", editable=False, confidence="unknown")
        files = {}
        variants = set()
        for directory, dirs, names in os.walk(theme, followlinks=False):
            for entry in list(dirs):
                if (Path(directory) / entry).is_symlink():
                    dirs.remove(entry)
                    report["skipped_symlinks"] += 1
            for filename in sorted(names):
                path = Path(directory) / filename
                if path.suffix.lower() != ".svg":
                    continue
                report["svg_files"] += 1
                variant = re.match(r"folder-(blue|red|green|yellow|orange|violet|cyan|magenta|purple|pink|brown|grey|gray|black|white|teal)(?:[.-]|$)", filename)
                if variant:
                    variants.add(variant[1])
                try:
                    target = path.resolve(strict=True)
                    if not inside(target, theme) or not target.is_file():
                        report["skipped_symlinks"] += 1
                        continue
                except (OSError, RuntimeError):
                    report["skipped_symlinks"] += 1
                    continue
                symbolic = filename.endswith("-symbolic.svg") or "symbolic" in path.relative_to(theme).parts
                if target in files:
                    files[target]["symbolic"] |= symbolic
                else:
                    files[target] = {"symbolic": symbolic}
        accents = set()
        editable_accents = set()
        for path, item in sorted(files.items()):
            report["unique_svg_files"] += 1
            try:
                data = path.read_bytes()
                root = validate_svg(data)
                symbolic, gpa = GTKSymbolicBackend.detect(path.relative_to(theme), root, data)
                symbolic |= item["symbolic"]
                edits, users = KDEColorSchemeBackend.detect(data, root)
                item.update(data=data, edits=edits, symbolic=symbolic, mode=stat.S_IMODE(path.stat().st_mode))
                report["highlight_users"] += users
                report["gtk_symbolic"] += bool(symbolic)
                report["gtk_gpa_accent"] += bool(gpa)
                if edits:
                    report["kde_matched"] += 1
                    accents.update(edit[2] for edit in edits)
                if not edits and not symbolic and not gpa:
                    report["static_svg"] += 1
                item["editable"] = bool(edits) and not symbolic and not gpa
                if item["editable"]:
                    report["editable_svg_files"] += 1
                    editable_accents.update(edit[2] for edit in edits)
            except (OSError, ValueError, ET.ParseError, expat.ExpatError) as exc:
                report["invalid_svg"].append({"file": str(path.relative_to(theme)), "error": str(exc)})
                item["editable"] = False
        report["folder_variants"] = sorted(variants)
        report["accents"] = sorted(accents)
        report["editable_accents"] = sorted(editable_accents)
        active = report["editable_accents"] or report["accents"]
        report["accent"] = active[0] if len(active) == 1 else None
        report["editable"] = any(item["editable"] for item in files.values())
        if report["kde_matched"]:
            report["backend"] = "kde-colorscheme"
        elif report["gtk_symbolic"] or report["gtk_gpa_accent"]:
            report["backend"] = "gtk-symbolic"
        report["confidence"] = "high" if report["editable"] else "unknown"
        return report, files


def atomic_write(path, data, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".icon-accent-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fchmod(stream.fileno(), mode)
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


class BackupManager:
    def __init__(self, theme):
        base = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser()
        key = theme.name + "-" + digest(str(theme).encode())[:16]
        self.directory = base / "icon-accent" / key
        self.path = self.directory / "state.json"
        self.theme = theme

    @contextlib.contextmanager
    def lock(self):
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (self.directory / "lock").open("a") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            yield

    def load(self):
        if not self.path.exists():
            return None
        state = json.loads(self.path.read_text())
        if state.get("location") != str(self.theme) or state.get("backend") != "kde-colorscheme" or not isinstance(state.get("files"), dict):
            raise ValueError("invalid backup state")
        for relative, entry in state["files"].items():
            target = self.theme / relative
            if Path(relative).is_absolute() or ".." in Path(relative).parts or target.resolve() != target or not inside(target, self.theme):
                raise ValueError(f"unsafe backup path: {relative}")
            backup = self.directory / "backup" / relative
            if not inside(backup.resolve(), (self.directory / "backup").resolve()):
                raise ValueError(f"unsafe backup target: {relative}")
            if digest(backup.read_bytes()) != entry["original_sha256"]:
                raise ValueError(f"backup checksum mismatch: {relative}")
        return state

    def save(self, state):
        atomic_write(self.path, (json.dumps(state, indent=2) + "\n").encode())


def refresh_cache(theme):
    command = shutil.which("gtk-update-icon-cache")
    if command and (theme / "icon-theme.cache").is_file() and not (theme / "icon-theme.cache").is_symlink():
        try:
            result = subprocess.run([command, "-f", str(theme)], capture_output=True, timeout=30)
            if result.returncode:
                print("Icon cache refresh failed; restart the application if needed.", file=sys.stderr)
        except (OSError, subprocess.TimeoutExpired):
            print("Icon cache refresh failed; restart the application if needed.", file=sys.stderr)


def verify_target(path, theme, expected):
    if path.resolve(strict=True) != path or not inside(path, theme) or path.read_bytes() != expected:
        raise ValueError(f"file changed during operation: {path}")


def set_accent(scanner, name, color, dry_run=False):
    theme = scanner.theme(name)
    backups = BackupManager(theme)
    with contextlib.nullcontext() if dry_run else backups.lock():
        report, files = scanner.scan(name)
        print(f"Theme: {name}\nBackend: {report['backend']}")
        if not report["editable"]:
            raise AccentError("unsupported theme: no safely editable KDE highlight rules", 4)
        changes = []
        for path, item in files.items():
            if item["editable"]:
                updated = KDEColorSchemeBackend.patch(item["data"], item["edits"], color)
                if updated != item["data"]:
                    changes.append((path, item, updated))
        print(f"Accent: {', '.join(report['editable_accents'])} -> {color}")
        print(f"Matched SVGs: {report['kde_matched']}\nFiles requiring modification: {len(changes)}")
        print(f"Skipped {report['static_svg']} static SVG files; {report['gtk_symbolic']} GTK runtime symbolic files; {len(report['invalid_svg'])} invalid/unsupported XML files.")
        if dry_run:
            print("No files changed (--dry-run).")
            return
        if not changes:
            print("Accent already set; no files changed.")
            return
        state = backups.load() or dict(theme=name, location=str(theme), backend="kde-colorscheme",
                                       original_accent=report["editable_accents"], current_accent=None, files={})
        for path, item, updated in changes:
            relative = str(path.relative_to(theme))
            verify_target(path, theme, item["data"])
            if relative in state["files"]:
                entry = state["files"][relative]
                if digest(item["data"]) not in (entry["original_sha256"], entry["current_sha256"], entry.get("previous_sha256")):
                    raise ValueError(f"file edited externally; refusing overwrite: {relative}")
            else:
                atomic_write(backups.directory / "backup" / relative, item["data"])
                state["files"][relative] = dict(original_sha256=digest(item["data"]), mode=item["mode"])
            state["files"][relative]["previous_sha256"] = digest(item["data"])
            state["files"][relative]["current_sha256"] = digest(updated)
        state["current_accent"] = color
        # Persist all originals and planned hashes before modifying any theme file.
        backups.save(state)
        for path, item, updated in changes:
            verify_target(path, theme, item["data"])
            atomic_write(path, updated, item["mode"])
        print("Accent updated successfully.")
        refresh_cache(theme)
        print("Restart your file manager if icons remain cached.")


def restore(scanner, name):
    theme = scanner.theme(name)
    backups = BackupManager(theme)
    with backups.lock():
        state = backups.load()
        if state is None:
            print(f"{name}: no backup to restore.")
            return
        changes = []
        for relative, entry in state["files"].items():
            path = theme / relative
            current = path.read_bytes()
            if digest(current) not in (entry["original_sha256"], entry["current_sha256"], entry.get("previous_sha256")):
                raise ValueError(f"file edited externally; refusing restore: {relative}")
            original = (backups.directory / "backup" / relative).read_bytes()
            validate_svg(original)
            if original != current:
                changes.append((path, current, original, entry["mode"]))
        for path, current, original, mode in changes:
            verify_target(path, theme, current)
            atomic_write(path, original, mode)
        state["current_accent"] = state["original_accent"]
        for entry in state["files"].values():
            entry["current_sha256"] = entry["original_sha256"]
        backups.save(state)
        print(f"{name}: restored {len(changes)} files from original backups.")
        refresh_cache(theme)


def print_report(report):
    yes = lambda value: "yes" if value else "no"
    print(f"Theme\n  {report['theme']}\nLocation\n  {report['location']}")
    print(f"SVG files\n  {report['svg_files']} paths, {report['unique_svg_files']} unique targets")
    print("Detected mechanisms")
    print(f"  KDE ColorScheme       {yes(report['kde_matched'])}")
    print(f"  GTK symbolic          {report['gtk_symbolic']} (recolor mode: runtime)")
    print(f"  GTK GPA accent aware  {yes(report['gtk_gpa_accent'])}")
    print(f"  Static SVG palette    {report['static_svg']} (automatic recoloring: unsafe)")
    print(f"Folder color variants\n  {', '.join(report['folder_variants']) or 'none'}")
    print(f"KDE accent\n  {', '.join(report['accents']) or 'none'}")
    print(f"Editable KDE accent\n  {', '.join(report['editable_accents']) or 'none'} ({report['editable_svg_files']} files)")
    print(f"ColorScheme-Highlight users\n  {report['highlight_users']}")
    print(f"Supported automatic operation\n  set accent: {yes(report['editable'])}")
    print(f"Confidence\n  {report['confidence']}")
    print(f"Skipped symlinks: {report['skipped_symlinks']}; invalid SVGs: {len(report['invalid_svg'])}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--icons-dir", default=str(Path.home() / ".icons"))
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list")
    for command in ("inspect", "status"):
        sub = commands.add_parser(command)
        sub.add_argument("theme")
        sub.add_argument("--json", action="store_true")
    sub = commands.add_parser("set")
    sub.add_argument("color", type=normalize_color)
    group = sub.add_mutually_exclusive_group(required=True)
    group.add_argument("--theme")
    group.add_argument("--all", action="store_true")
    sub.add_argument("--dry-run", action="store_true")
    sub = commands.add_parser("restore")
    group = sub.add_mutually_exclusive_group(required=True)
    group.add_argument("theme", nargs="?")
    group.add_argument("--all", action="store_true")
    args = parser.parse_args(argv)
    try:
        scanner = ThemeScanner(args.icons_dir)
        if args.command == "list":
            print(f"{'Theme':40} {'Type':18} Accent support")
            for name in scanner.themes():
                report, _ = scanner.scan(name)
                kind = "KDE-compatible" if report["kde_matched"] else "GTK symbolic" if report["backend"] == "gtk-symbolic" else "Static SVG"
                support = "yes" if report["editable"] else "runtime" if report["gtk_symbolic"] or report["gtk_gpa_accent"] else "unknown"
                print(f"{name:40} {kind:18} {support}")
        elif args.command in ("inspect", "status"):
            report, _ = scanner.scan(args.theme)
            if args.json:
                print(json.dumps(report, indent=2))
            elif args.command == "status":
                print("\n".join(report["editable_accents"] or report["accents"]) or ("runtime" if report["backend"] == "gtk-symbolic" else "unknown"))
            else:
                print_report(report)
        else:
            names = scanner.themes() if args.all else [args.theme]
            code = 0
            for name in names:
                try:
                    if args.command == "set":
                        if args.all and not scanner.scan(name)[0]["editable"]:
                            print(f"{name}: skipped (no high-confidence editable accent).")
                            continue
                        set_accent(scanner, name, args.color, args.dry_run)
                    else:
                        restore(scanner, name)
                except AccentError as exc:
                    print(str(exc), file=sys.stderr)
                    code = max(code, exc.code)
                except (OSError, ValueError, KeyError, TypeError, ET.ParseError, expat.ExpatError) as exc:
                    print(f"{name}: modification/validation failed: {exc}", file=sys.stderr)
                    code = 5
            return code
        return 0
    except AccentError as exc:
        print(str(exc), file=sys.stderr)
        return exc.code
    except (OSError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
