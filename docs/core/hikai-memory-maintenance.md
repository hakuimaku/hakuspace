# Hikai memory maintenance

## Pre-implementation audit

The root shell retains IPC, lock ownership, notification server/history, screen
hosts and wallpaper ownership. Services retain settings/text drafts, wallpaper
records, application/window metadata and bounded notification history. These are
intentional lifetime owners, not evidence of a leak.

`LifecycleLoader` unloads after `releaseReady`; `EphemeralSurfaces` counts loaded
trees, including closing animations. HakuMenu has three additional lifecycle
loaders. Dashboard instantiates current/incoming/outgoing widget slots only.
Image editor clears document arrays on completed close; its undo history and
annotations already have limits. Native dialogs use UiState leases.

Navigator's only `ScreencopyView` lives inside `WindowPreview`. Capture is still,
not continuous. Overlay content loaders unload when invisible, the outer host
unloads after close/focus handoff, and `finishClose` clears `sessionWindows`.
Window metadata contains live toplevel QObjects intentionally while windows
exist; MRU addresses are pruned against live windows. No confirmed capture leak
was found by source inspection. Driver/buffer release still needs hardware tests.

Notification records are bounded to 100 closed records while retaining every
live protocol handle. Handles/deadlines are removed on close; presentation records
contain no notification/action QObjects. Signal closures belong to the native
notification sender. Live notifications can legitimately exceed the history cap.

Action-menu pages have explicit parents, stack clearing and reverse-morph
destruction. WM backend objects are parented to the singleton. Wallpaper has two
owned video slots with destroy paths; video/decoder resources live in a separate
Quickshell child. Wallpaper lists replace previous lists. Image source budgets,
async decoding and selective uncached large images are already present.

Timers/Connections are declarative with their owners; existing audio/brightness
reads coalesce. No confirmed repeated timer/connection allocation or append-only
unbounded QObject collection was identified. Tooltip services retain only the
current target, released by the corresponding control. Qt caches, scene graph,
Wayland resources and allocator retention remain unknown until measured.

FD/thread/child growth cannot be established by code inspection. Before/after
profiling uses an isolated two-output software-rendered Wayland session, not the
user's compositor. Hardware screencopy and lock/PAM checks must be reported
separately. Maintenance must not be presented as a proven leak fix.

Follow-up inspection confirmed retention in the resident generic picker: closing
it left the last item/filter arrays, typed input and writer environment payload
reachable. The fix clears models/input on close and the response environment on
writer exit, preserving FIFO delivery. This is last-session retention, not proof
of the reported unbounded 400–600 MB growth. Classic's canonical picker path uses
Rofi and is unchanged.

## Runtime architecture

The root shell lazily loads `MemoryMaintenanceHost` only while
`AppState.shellBackend === "hikai"`. That host binds scalar counts and blocker
names into the `MemoryMaintenance` singleton, and owns the `memory` IPC target.
The singleton never imports UI components. Classic has no maintenance host, IPC,
sampling timers or helpers. A backend handoff stops all owned maintenance work.

The host counts all ephemeral and HakuMenu loaders through visual teardown and
focus handoff. It also blocks on lock/unlock reveal, shell transitions, picker
FIFO writes, native dialog leases, image-editor drafts/exports, settings/config
drafts and commits, text/avatar saves, wallpaper preparation/cache work/incoming
video slots and session sleep/recovery. Every blocker must stay absent through
the quiet interval. This is shell interaction quiet, not system-wide user idle.

`hikai_memory_ctl.py` runs once per sparse sample, reads `/proc` directly and
exits. It launches no shell sampling loop and retains no resident Python worker.
`haku_memory.py` is shared with the existing soak profiler. RSS/PSS, FD/thread/
direct-child counts are available in status; unavailable PSS is null. Optional
DRM residency requires `gpu: true`, deduplicates device/client IDs, and remains
null on unsupported/software renderers. It does not estimate GPU memory from RSS.
FD target classification happens only in debug or after an anomaly, and exposes
categories rather than paths. Persistent anomalies and debug sampling refresh
classification at most once per 15 minutes, using existing sample requests.
A recovered/new anomaly can start classification again immediately.

## Internal policy

Edit `config/Memory.js`; there is no Settings UI or user preference migration.

| Policy | Default |
| --- | --- |
| Steady sampling | 5 minutes |
| Startup/reload warmup | 90 seconds |
| Baseline | median of 3 quiet samples, 15 seconds apart |
| Continuous shell quiet | 30 seconds |
| History and event limits | 24 each |
| Soft/hard RSS growth | baseline +150 / +300 MiB |
| GC cooldown | 20 minutes |
| Post-GC observation delay | 20 seconds |
| Meaningful reclaim | at least 20 MiB, paired PSS preferred |
| Retry after ineffective collection below hard pressure | 2 hours |
| Maximum GC evidence age for auto recycle | 10 minutes |
| Recycle cooldown | 2 hours |
| Recycle loop cap | 2 attempts per rolling 24 hours |
| FD anomaly | baseline +32 descriptors |
| FD classification refresh | 15 minutes |
| Maximum sample age for automatic effects | sampling interval +60 seconds (6 minutes) |
| Detailed sample logging / DRM scans | off / off |

Baseline acquisition uses its shorter interval only while shell activity is
safe; an open editor or lock does not cause indefinite 15-second subprocess
polling. An idle transition requests a fresh sample before any pending action.

`MemoryPolicy.js` implements the decision table: disabled, warming-up, normal,
stale, soft-pressure, gc-pending, gc-observing, hard-pressure, recycle-pending,
cooldown and fd-growth. FD growth takes precedence over heap maintenance.

## Collection and recycling

Automatic GC requires pressure, quiet activity and cooldown. Manual GC bypasses
only pressure. Both paths obtain a fresh pre-GC sample and recheck safety before
calling `gc()`. Post-GC sampling waits for the observation delay. Status retains
both metric pairs, timestamps, signed reclaimed MiB and whether PSS or RSS was
used. Allocation during observation can produce a negative reclaimed value.
The GC counter is local to an engine generation.

Automatic recycling additionally requires a recent ineffective GC from the same
pressure episode and RSS still above the hard threshold. A manual collection
under normal memory use cannot authorize a later automatic recycle. Unknown,
prerelease or older Quickshell versions disable recycling while telemetry and GC
continue. Version detection queries `/proc/<shell-pid>/exe --version`, not a
possibly different binary on PATH. The helper rechecks version when reserving.

If ineffective GC evidence expires while hard pressure persists, collection can
retry after the normal 20-minute GC cooldown to obtain new evidence. It does not
wait for the two-hour ineffective backoff. Safety, FD, freshness and post-recycle
cooldown gates still apply; stale GC evidence never authorizes recycling.

Recycle attempts use the registered `shell.memory-maintenance.json` state key,
resolved by both existing Bash/Python registries. Directory locking and atomic,
flushed JSON replacement reserve cooldown before `Quickshell.reload(false)`.
Attempts remain counted when safety changes mid-write or reload fails. The final
callback checks activity again before reload. Corrupt/unreadable protection state
disables recycling without failing shell startup. Cooldown survives singleton
reset, engine reload and process restart; a backward clock jump defers attempts.
Each new engine acquires a new baseline after warmup. GC is also deferred during
the first GC cooldown interval following a recycle.

This does not clear disk cache, restart the shell process, tune the allocator,
enable software rendering in production, or promise that Qt/driver RSS will fall
after an engine reload.

## IPC

```bash
qs -c hakuspace ipc call memory status
qs -c hakuspace ipc call memory baseline
qs -c hakuspace ipc call memory collect
qs -c hakuspace ipc call memory recycle
```

`status` is bounded JSON containing counters, baseline, thresholds, activity
blockers, sample age, pre/post GC snapshots, recent events, version guard and
persisted recycle attempts. `baseline` reads the current baseline; it never
resets it. Manual effect commands return `scheduled` or `rejected: ...` and
status/events expose completion. Recycle still enforces version, safety,
observation, FD and persistent cooldown gates. There is no developer force bypass.

## Reproducible validation

```bash
node tests/hikai/memory/test_maintenance.js
python3 tests/hikai/memory/test_maintenance.py
python3 tests/hikai/memory/test_lifecycle.py
python3 tests/config/state/test_naming.py
```

The runtime test uses a private offscreen software shell, shortened durations,
real `gc()` and actual engine reload. It tests startup, fresh measurements,
manual collection, unsafe deferral, cooldown, ineffective GC, automatic/manual
recycling, persisted attempts, FD suppression and shutdown. Helper tests cover
actual pipe growth, classification, concurrent reservations, invalid protection
state, version parsing and Bash/Python path agreement.

Regression checks cover expired ineffective-GC evidence under hard pressure,
`freshMs > sampleMs` and sparse FD classification during a persistent anomaly.
The shortened runtime fixture verifies a new GC before the ineffective backoff
expires and a later FD classification timestamp without GC during fd-growth.

Picker profiling uses 10,000 items and a real private FIFO. It asserts successful
delivery, zero retained model entries and completion of the writer. The same test
fails on the pre-change source snapshot with 20,000 retained item/filter entries
despite successful FIFO delivery.

The profiler retains live-PID sampling and adds source-snapshot comparisons,
active-layer/maintenance snapshots, deltas, editor loops and a forced-pressure
editor check. Navigator profiles explicitly report unsupported compositors.
Private profiles disable idle actions and system D-Bus access. They use a valid
synthetic PNG rather than user images and drive only the private Quickshell PID.

```bash
python3 tools/profiling/hikai_memory_soak.py --headless --software \
  --output /tmp/hikai-memory-pressure.json --warmup 4 --seconds 1 --cycles 0 \
  --maintenance-check --maintenance-policy \
  '{"warmupMs":500,"baselineSampleMs":200,"idleMs":300,"sampleMs":300,"observationMs":300,"gcCooldownMs":20000}'

python3 tools/profiling/hikai_memory_soak.py --headless --software \
  --backend classic --output /tmp/hikai-memory-classic.json \
  --warmup 3 --seconds 2 --cycles 0

python3 tools/profiling/hikai_memory_soak.py --headless --software \
  --output /tmp/hikai-memory-picker-after.json --warmup 3 --seconds 1 \
  --cycles 0 --picker-check

HAKUSPACE_NAV_MEMORY_LOOPS=100 HAKUSPACE_NAV_MEMORY_WARMUP_MS=120000 \
HAKUSPACE_NAV_TIMEOUT=300s HAKUSPACE_NAV_ARTIFACT_DIR=/tmp/hikai-memory-navigator \
  bash tests/hikai/window_navigator/test_runtime.sh
```

Policy overrides rewrite only the disposable headless copy. Classic validation
also checks that the `memory` IPC target is absent. The optional Navigator soak
uses the existing nested Hyprland runtime test, disposable native windows and
actual screencopy. Its copied preview component counts ScreencopyView creation
and destruction, with no production instrumentation. It samples RSS/PSS/FD/DRM
only after visual teardown; every close must destroy all capture objects. Shell
and compositor logs remain in the requested artifact directory. Direct hardware
session behavior, multi-hour growth, native dialogs, real video transitions and
lock/PAM remain separate acceptance checks.

## Matched software soak results — 2026-10-29

Both sessions used Quickshell 0.3.2, two headless Labwc outputs, software Qt Quick,
120-second warmup, 120-second idle observation, identical settle/dwell durations,
two batches of ten opens/closes each for Settings, wallpaper, Dashboard, HakuMenu
and image editor (100 opens total), followed by 110 notifications. Baseline source
was the unchanged Git snapshot; after source used production maintenance policy.
The picker fix was tested separately; these workflows never opened the picker.

| Parent process measurement | Before | After |
| --- | ---: | ---: |
| Duration | 501.671 s | 501.566 s |
| First post-warmup idle RSS | 221.11 MiB | 221.05 MiB |
| First post-warmup idle PSS | 137.32 MiB | 132.12 MiB |
| Final RSS | 278.42 MiB | 283.63 MiB |
| Final PSS | 177.15 MiB | 172.87 MiB |
| Final FD / threads / direct children | 50 / 13 / 0 | 50 / 13 / 0 |
| Idle parent CPU | 0.35% | 0.27% |
| Total parent CPU time | 26.71 s | 28.17 s |
| GPU resident | unavailable | unavailable |

All closed batches had zero loaded surfaces. The after service established a
220.98 MiB RSS / 132.05 MiB PSS median, stayed normal and requested zero GC or
recycles. Parent CPU excludes sampling helper CPU; sparse telemetry samples can
include their own helper child/pipe descriptors, while external settled samples
can observe a different instant. Status includes sample timestamps/age for this
reason. These small RSS/PSS/CPU differences do not establish a memory saving.
Two repeated batches cannot prove a multi-hour bound or explain the user's
400–600 MB report.

Artifacts: `/tmp/hikai-memory-before-final.json`,
`/tmp/hikai-memory-after-final.json` and their `.qs.log` / `.log` siblings.
The editor forced-pressure artifact is `/tmp/hikai-memory-pressure.json`: while
editing it reported gc-pending, one loaded surface and zero GC; after teardown,
one collection and zero loaded surfaces. Paired PSS reclaim in that run was
-0.166 MiB, correctly reported as ineffective rather than a leak fix.
`/tmp/hikai-memory-classic.json` records absent maintenance runtime; picker
before/after artifacts are `/tmp/hikai-memory-picker-before.json` (expected
regression failure) and `/tmp/hikai-memory-picker-after.json` (pass).

Scoped validation passed for QML syntax, Python compilation, Bash syntax, the
memory policy checks, seven maintenance helper/runtime tests, three existing
memory lifecycle checks and ten state naming checks. A whole-file whitespace
probe flagged pre-existing Picker formatting; it was left unchanged.
`git diff --check` passed. The repository-wide suite and unrelated component/WM
tests were intentionally not run.

## Navigator capture soak

The regular nested Hyprland runtime test passed with keyboard, pointer, actual
still previews, close/reopen reversal, focus handoff, output removal and snapshot
release. The extended run then warmed for 120 seconds and repeated the same
two-window overview workload 100 times, sampling after every complete teardown.
Graphics used the default backend with real DRM resident counters, separately
from the software-rendered matched runs above.

| Cycle | RSS MiB | PSS MiB | DRM resident MiB | FD |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 305.81 | 169.29 | 124.75 | 69 |
| 10 | 306.05 | 169.47 | 169.98 | 69 |
| 25 | 307.48 | 170.96 | 141.79 | 69 |
| 50 | 307.86 | 171.34 | 142.10 | 69 |
| 75 | 307.84 | 171.32 | 141.79 | 69 |
| 100 | 307.62 | 171.10 | 142.10 | 69 |

All 101 checkpoints had zero live capture objects. Creation and destruction were
227/227 (27 during interaction checks and 200 during the repeated workload).
FD/thread/direct-child counts stayed 69/30/3; two test input helpers plus the
finite sampler explain the child count. RSS/PSS ranges were 303.48–308.76 /
166.97–172.24 MiB. DRM resident ranged 124.75–171.73 MiB and oscillated rather
than increasing monotonically. Buffer/cache retention is plausible, not a
confirmed allocator or driver diagnosis. No maintenance GC/recycle ran in this
capture-only fixture, so it cannot conceal capture retention.

The first extended attempt lost every nested output and the external Hyprland
compositor crashed before loop 1. Its initial checkpoint still showed 27/27
capture destruction. The soak fixture now creates a dedicated headless output
after the output-removal interaction check. The repeated run passed; no
production compositor or Navigator behavior was modified.

Successful artifacts: `/tmp/hikai-memory-navigator-final/{report.json,shell.log,compositor.log}`.
The failed external-compositor run remains under `/tmp/hikai-memory-navigator/`.
These results support bounded growth within this fixed 100-cycle workload only;
they do not rule out a longer-term driver/scene-graph leak in a real desktop.

## Changed files

- Runtime: `shell.qml`, `components/MemoryMaintenanceHost.qml`,
  `services/MemoryMaintenance.qml`, `services/MemoryPolicy.js`, `services/qmldir`.
- Developer policy: `config/Memory.js`, `config/README.md`.
- Safety/retention: `modules/picker/Picker.qml`, `services/WallpaperService.qml`.
- Backend/state: `src/core/backend/system/hikai_memory_ctl.py`,
  `src/core/lib/{haku_memory.py,haku_state.py,haku_state.sh}`.
- Tests: `tests/hikai/memory/{test_maintenance.py,test_maintenance.js,harness/maintenance.qml}`,
  `tests/hikai/window_navigator/{test_runtime.sh,harness/navigator.qml}`.
- Profiling: `tools/profiling/{hikai_memory_soak.py,harness/memory.qml}`.
- Documentation: `docs/core/{hikai-memory-maintenance.md,state.md}`.

Shell runtime paths above are relative to
`src/home/.config/quickshell/hakuspace/`. No commit was created.
