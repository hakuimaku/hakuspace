#!/usr/bin/env python3
"""On-demand PipeWire/PulseAudio mixer controller for Hikai Dashboard."""

import json
import math
import re
import shutil
import subprocess
import sys

TIMEOUT_SEC = 2.5
PA_VOLUME_NORM = 65536.0
WPCTL_ENTRY_RE = re.compile(r"^\s*(\*?)\s*(\d+)\.\s+(.+?)\s*$")
WPCTL_VOL_RE = re.compile(r"vol:\s*([0-9]+(?:\.[0-9]+)?)")
USAGE_TEXT = (
    "Usage: dashboard_devices_ctl.py "
    "<status|set-sink|set-source|set-sink-volume|set-sink-mute|"
    "set-source-volume|set-source-mute|set-stream-volume|set-stream-mute|move-stream>"
)


def run_cmd(args: list[str]) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SEC,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None


def _ok_json() -> int:
    sys.stdout.write('{"ok": true}\n')
    return 0


def _fail_json(message: str) -> int:
    sys.stdout.write(json.dumps({"ok": False, "error": message}, ensure_ascii=False) + "\n")
    return 1


def _clean_target(value: str) -> str | None:
    if not isinstance(value, str):
        return None
    clean = value.strip()
    if not clean or clean.startswith("-") or "\x00" in clean or "\n" in clean or "\r" in clean:
        return None
    return clean


def _clean_stream_id(value: str) -> str | None:
    clean = _clean_target(value)
    if clean is None or not clean.isdigit():
        return None
    return clean


def _parse_percent(value: str) -> int | None:
    if not isinstance(value, str):
        return None
    clean = value.strip()
    if not clean:
        return None
    try:
        parsed = float(clean)
    except ValueError:
        return None
    if not math.isfinite(parsed):
        return None
    return max(0, min(150, int(round(parsed))))


def _clean_mute_arg(value: str) -> str | None:
    if not isinstance(value, str):
        return None
    clean = value.strip().lower()
    if clean in ("toggle", "0", "1"):
        return clean
    return None


def _is_bool_like(val: object) -> bool:
    if isinstance(val, bool):
        return val
    if isinstance(val, str):
        return val.strip().lower() in ("yes", "true", "1")
    return False


def _is_muted_pactl(item: dict) -> bool:
    return _is_bool_like(item.get("mute"))


def _parse_pactl_volume(item: dict) -> int:
    volume = item.get("volume")
    if not isinstance(volume, dict):
        return 0

    percents: list[float] = []
    for channel in volume.values():
        if not isinstance(channel, dict):
            continue
        pct_raw = channel.get("value_percent")
        parsed_pct: float | None = None
        if isinstance(pct_raw, str):
            stripped = pct_raw.strip().rstrip("%").strip()
            if stripped:
                try:
                    val = float(stripped)
                    if math.isfinite(val):
                        parsed_pct = val
                except ValueError:
                    parsed_pct = None
        if parsed_pct is None:
            raw_val = channel.get("value")
            if isinstance(raw_val, (int, float)) and math.isfinite(float(raw_val)):
                parsed_pct = (float(raw_val) / PA_VOLUME_NORM) * 100.0
        if parsed_pct is not None:
            percents.append(parsed_pct)

    if not percents:
        return 0
    avg = sum(percents) / len(percents)
    return max(0, min(150, int(round(avg))))


def _pactl_description(item: dict) -> str:
    props = item.get("properties")
    if isinstance(props, dict):
        for key in ("node.nick", "node.description"):
            val = props.get(key)
            if isinstance(val, str) and val.strip():
                return val.strip()
    desc = item.get("description")
    if isinstance(desc, str) and desc.strip():
        return desc.strip()
    if isinstance(props, dict):
        for key in ("device.description", "alsa.card_name"):
            val = props.get(key)
            if isinstance(val, str) and val.strip():
                return val.strip()
    name = item.get("name")
    return str(name) if name else ""


def _pactl_json_list(kind: str) -> list[dict]:
    res = run_cmd(["pactl", "-f", "json", "list", kind])
    if not res or res.returncode != 0:
        return []
    try:
        parsed = json.loads(res.stdout or "[]")
    except json.JSONDecodeError:
        return []
    if not isinstance(parsed, list):
        return []
    return [item for item in parsed if isinstance(item, dict)]


def enumerate_pactl() -> tuple[str, list[dict], list[dict], list[dict]]:
    def_sink_res = run_cmd(["pactl", "get-default-sink"])
    def_source_res = run_cmd(["pactl", "get-default-source"])
    default_sink = def_sink_res.stdout.strip() if def_sink_res and def_sink_res.returncode == 0 else ""
    default_source = def_source_res.stdout.strip() if def_source_res and def_source_res.returncode == 0 else ""

    sinks: list[dict] = []
    sink_by_id: dict[str, dict] = {}
    for item in _pactl_json_list("sinks"):
        name = str(item.get("name") or "")
        if not name:
            continue
        idx = item.get("index")
        entry = {
            "id": str(idx) if idx is not None else name,
            "name": name,
            "description": _pactl_description(item) or name,
            "isDefault": name == default_sink,
            "muted": _is_muted_pactl(item),
            "volumePercent": _parse_pactl_volume(item),
        }
        sinks.append(entry)
        if idx is not None:
            sink_by_id[str(idx)] = entry
        sink_by_id[name] = entry

    sources: list[dict] = []
    for item in _pactl_json_list("sources"):
        name = str(item.get("name") or "")
        if not name or name.endswith(".monitor"):
            continue
        if item.get("monitor_of") is not None or bool(item.get("monitor_source")):
            continue
        idx = item.get("index")
        sources.append(
            {
                "id": str(idx) if idx is not None else name,
                "name": name,
                "description": _pactl_description(item) or name,
                "isDefault": name == default_source,
                "muted": _is_muted_pactl(item),
                "volumePercent": _parse_pactl_volume(item),
            }
        )

    streams: list[dict] = []
    for item in _pactl_json_list("sink-inputs"):
        idx = item.get("index")
        if idx is None:
            continue
        props = item.get("properties") if isinstance(item.get("properties"), dict) else {}
        app_name = ""
        for key in ("application.name", "node.name", "application.process.binary"):
            val = props.get(key)
            if isinstance(val, str) and val.strip():
                app_name = val.strip()
                break
        if not app_name:
            app_name = "Audio Stream"

        media_name = ""
        for key in ("media.name", "media.title"):
            val = props.get(key)
            if isinstance(val, str) and val.strip():
                media_name = val.strip()
                break

        sink_raw = item.get("sink")
        sink_id = str(sink_raw) if sink_raw is not None else ""
        sink_entry = sink_by_id.get(sink_id)
        sink_name = sink_entry["description"] if sink_entry else (f"Sink {sink_id}" if sink_id else "")

        streams.append(
            {
                "id": str(idx),
                "appName": app_name,
                "mediaName": media_name,
                "sinkId": sink_id,
                "sinkName": sink_name,
                "muted": _is_muted_pactl(item),
                "volumePercent": _parse_pactl_volume(item),
                "corked": _is_bool_like(item.get("corked")),
            }
        )

    return "pactl", sinks, sources, streams


def enumerate_wpctl() -> tuple[str, list[dict], list[dict], list[dict]]:
    res = run_cmd(["wpctl", "status"])
    if not res or res.returncode != 0:
        return "wpctl", [], [], []

    sinks: list[dict] = []
    sources: list[dict] = []
    in_audio = False
    section = ""

    for raw_line in (res.stdout or "").splitlines():
        cleaned = (
            raw_line.replace("├─", " ")
            .replace("└─", " ")
            .replace("│", " ")
            .rstrip()
        )
        stripped = cleaned.strip()
        if not stripped:
            continue

        if stripped == "Audio":
            in_audio = True
            section = ""
            continue
        if in_audio and stripped in ("Video", "Settings"):
            in_audio = False
            section = ""
            continue
        if not in_audio:
            continue

        if stripped.startswith("Sinks:"):
            section = "sinks"
            continue
        if stripped.startswith("Sources:"):
            section = "sources"
            continue
        if stripped.endswith(":") and stripped[:-1] in (
            "Devices",
            "Filters",
            "Streams",
            "Sink endpoints",
            "Source endpoints",
        ):
            section = ""
            continue

        if section not in ("sinks", "sources"):
            continue

        match = WPCTL_ENTRY_RE.match(stripped)
        if not match:
            continue

        is_default = match.group(1) == "*"
        node_id = match.group(2)
        rest = match.group(3)
        muted = "MUTED" in rest
        vol_match = WPCTL_VOL_RE.search(rest)
        vol_pct = 100
        if vol_match:
            try:
                vol_pct = max(0, min(150, int(round(float(vol_match.group(1)) * 100.0))))
            except ValueError:
                vol_pct = 100
        desc = re.sub(r"\s*\[[^\]]*\]\s*$", "", rest).strip() or f"Device {node_id}"
        entry = {
            "id": node_id,
            "name": node_id,
            "description": desc,
            "isDefault": is_default,
            "muted": muted,
            "volumePercent": vol_pct,
        }
        if section == "sinks":
            sinks.append(entry)
        else:
            sources.append(entry)

    return "wpctl", sinks, sources, []


def cmd_status() -> int:
    if shutil.which("pactl") is not None:
        backend, sinks, sources, streams = enumerate_pactl()
    elif shutil.which("wpctl") is not None:
        backend, sinks, sources, streams = enumerate_wpctl()
    else:
        backend, sinks, sources, streams = "none", [], [], []

    payload = {
        "backend": backend,
        "sinks": sinks,
        "sources": sources,
        "streams": streams,
    }
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    return 0


def _run_pactl_action(args: list[str]) -> int:
    if shutil.which("pactl") is None:
        return _fail_json("pactl is not available")
    res = run_cmd(["pactl", *args])
    if res and res.returncode == 0:
        return _ok_json()
    err = res.stderr.strip() if res and res.stderr else "pactl failed"
    return _fail_json(err)


def cmd_set_default(kind: str, target: str) -> int:
    clean = _clean_target(target)
    if clean is None:
        return _fail_json("Invalid audio device target")

    has_pactl = shutil.which("pactl") is not None
    has_wpctl = shutil.which("wpctl") is not None

    if has_pactl:
        old_default_sink_id: str | None = None
        if kind == "sink":
            old_def_res = run_cmd(["pactl", "get-default-sink"])
            old_default_name = (
                old_def_res.stdout.strip()
                if old_def_res and old_def_res.returncode == 0
                else ""
            )
            if old_default_name:
                for sink in _pactl_json_list("sinks"):
                    if str(sink.get("name") or "") == old_default_name and sink.get("index") is not None:
                        old_default_sink_id = str(sink["index"])
                        break

        subcmd = "set-default-sink" if kind == "sink" else "set-default-source"
        res = run_cmd(["pactl", subcmd, clean])
        if not res or res.returncode != 0:
            err = res.stderr.strip() if res and res.stderr else "pactl failed"
            return _fail_json(err)

        if kind == "sink":
            # Move streams attached to the previous default sink so playback follows immediately.
            for stream in _pactl_json_list("sink-inputs"):
                stream_idx = stream.get("index")
                if stream_idx is None:
                    continue
                stream_sink_id = str(stream.get("sink")) if stream.get("sink") is not None else ""
                if old_default_sink_id is None or stream_sink_id == old_default_sink_id:
                    run_cmd(["pactl", "move-sink-input", str(stream_idx), clean])

        return _ok_json()

    if has_wpctl and clean.isdigit():
        res = run_cmd(["wpctl", "set-default", clean])
        if res and res.returncode == 0:
            return _ok_json()
        err = res.stderr.strip() if res and res.stderr else "wpctl failed"
        return _fail_json(err)

    return _fail_json("No supported audio backend (pactl or wpctl) found")


def cmd_set_device_volume(kind: str, target: str, percent_raw: str) -> int:
    clean = _clean_target(target)
    if clean is None:
        return _fail_json("Invalid audio device target")
    percent = _parse_percent(percent_raw)
    if percent is None:
        return _fail_json("Invalid volume percentage")

    if shutil.which("pactl") is not None:
        subcmd = "set-sink-volume" if kind == "sink" else "set-source-volume"
        return _run_pactl_action([subcmd, clean, f"{percent}%"])

    if shutil.which("wpctl") is not None and clean.isdigit():
        res = run_cmd(["wpctl", "set-volume", clean, f"{percent / 100.0:.2f}"])
        if res and res.returncode == 0:
            return _ok_json()
        err = res.stderr.strip() if res and res.stderr else "wpctl failed"
        return _fail_json(err)

    return _fail_json("No supported audio backend (pactl or wpctl) found")


def cmd_set_device_mute(kind: str, target: str, mute_raw: str) -> int:
    clean = _clean_target(target)
    if clean is None:
        return _fail_json("Invalid audio device target")
    mute_arg = _clean_mute_arg(mute_raw)
    if mute_arg is None:
        return _fail_json("Invalid mute argument (expected toggle, 0, or 1)")

    if shutil.which("pactl") is not None:
        subcmd = "set-sink-mute" if kind == "sink" else "set-source-mute"
        return _run_pactl_action([subcmd, clean, mute_arg])

    if shutil.which("wpctl") is not None and clean.isdigit():
        res = run_cmd(["wpctl", "set-mute", clean, mute_arg])
        if res and res.returncode == 0:
            return _ok_json()
        err = res.stderr.strip() if res and res.stderr else "wpctl failed"
        return _fail_json(err)

    return _fail_json("No supported audio backend (pactl or wpctl) found")


def cmd_set_stream_volume(stream_raw: str, percent_raw: str) -> int:
    stream_id = _clean_stream_id(stream_raw)
    if stream_id is None:
        return _fail_json("Invalid stream id")
    percent = _parse_percent(percent_raw)
    if percent is None:
        return _fail_json("Invalid volume percentage")
    return _run_pactl_action(["set-sink-input-volume", stream_id, f"{percent}%"])


def cmd_set_stream_mute(stream_raw: str, mute_raw: str) -> int:
    stream_id = _clean_stream_id(stream_raw)
    if stream_id is None:
        return _fail_json("Invalid stream id")
    mute_arg = _clean_mute_arg(mute_raw)
    if mute_arg is None:
        return _fail_json("Invalid mute argument (expected toggle, 0, or 1)")
    return _run_pactl_action(["set-sink-input-mute", stream_id, mute_arg])


def cmd_move_stream(stream_raw: str, sink_raw: str) -> int:
    stream_id = _clean_stream_id(stream_raw)
    if stream_id is None:
        return _fail_json("Invalid stream id")
    sink_target = _clean_target(sink_raw)
    if sink_target is None:
        return _fail_json("Invalid sink target")
    return _run_pactl_action(["move-sink-input", stream_id, sink_target])


def main() -> int:
    if len(sys.argv) < 2:
        return _fail_json(USAGE_TEXT)

    action = sys.argv[1]
    argc = len(sys.argv)

    if action == "status" and argc == 2:
        return cmd_status()
    if action == "set-sink" and argc == 3:
        return cmd_set_default("sink", sys.argv[2])
    if action == "set-source" and argc == 3:
        return cmd_set_default("source", sys.argv[2])
    if action == "set-sink-volume" and argc == 4:
        return cmd_set_device_volume("sink", sys.argv[2], sys.argv[3])
    if action == "set-sink-mute" and argc == 4:
        return cmd_set_device_mute("sink", sys.argv[2], sys.argv[3])
    if action == "set-source-volume" and argc == 4:
        return cmd_set_device_volume("source", sys.argv[2], sys.argv[3])
    if action == "set-source-mute" and argc == 4:
        return cmd_set_device_mute("source", sys.argv[2], sys.argv[3])
    if action == "set-stream-volume" and argc == 4:
        return cmd_set_stream_volume(sys.argv[2], sys.argv[3])
    if action == "set-stream-mute" and argc == 4:
        return cmd_set_stream_mute(sys.argv[2], sys.argv[3])
    if action == "move-stream" and argc == 4:
        return cmd_move_stream(sys.argv[2], sys.argv[3])

    return _fail_json(USAGE_TEXT)


if __name__ == "__main__":
    sys.exit(main())
