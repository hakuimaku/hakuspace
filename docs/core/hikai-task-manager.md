# Hikai Task Manager V1.1

Updated: 2026-10-31 (Asia/Ho_Chi_Minh). This update completes process CPU semantics, frequency telemetry, Intel utilization and process-column correctness without redesigning the floating utility.

## Changed in V1.1

- `src/core/backend/system/task_manager_monitor.py`: explicit frequency metrics/source, independent AMD/Intel/NVIDIA providers, bounded Intel descriptor discovery and DRM client deltas; exclude firmware/BPF/GVfs/portal pseudo mounts observed during the disk audit.
- `src/home/.config/quickshell/hakuspace/components/taskmanager/TaskManagerLogic.js`: sort by normalized process CPU; GPU status formatting.
- `src/home/.config/quickshell/hakuspace/components/taskmanager/TaskManagerContent.qml`: normalized CPU, shared header/row component, keyboard lease guard.
- `src/home/.config/quickshell/hakuspace/components/taskmanager/TaskManagerProcessRow.qml`: new shared column geometry; full seven-digit PID, name elision, fixed readable numeric columns.
- `src/home/.config/quickshell/hakuspace/components/taskmanager/TaskManagerSummary.qml`: highest CPU frequency, Intel utilization/status/clock/power, shared-memory labeling.
- `src/home/.config/quickshell/hakuspace/components/TaskManagerOverlay.qml`: pass the lease to content and ignore Escape on its passive close button.
- `tests/hikai/task_manager/test_monitor.py`, `test_logic.js`, `harness/task_manager.qml`, `run.sh`: CPU/frequency/GPU correctness, PID rendering and ownership regressions.
- `docs/core/hikai-task-manager.md`: architecture, semantics, measured results and limitations.

Existing V1 changes to UiState, EphemeralSurfaces, Settings mask, memory-maintenance blocker, Sidebar, IPC, facade and service remain in the working tree. They were audited, not rewritten. SysStats, compositor bindings, process controller and Temp Note implementation were unchanged in this update.

## Architecture and lifecycle

`TaskManagerOverlay` is an independent floating utility, default 980 × 680 and minimum 720 × 480, clamped to its output. `EphemeralSurfaces` owns it through `LifecycleLoader`. The overlay acquires one `TaskManagerService` subscription on construction and releases it on destruction after its reversible close animation. The singleton launches one standard-library Python JSONL collector while there is demand and the backend is Hikai. The last release stops it and clears process objects, transient action state and histories (maximum 120 points).

The drawing window stays stable; dragging/resizing only changes the inner card. Temp Note remains visible during shared interaction-lease transfers. Keyboard handling, including Escape, requires Task Manager's lease. Settings subtracts both floating rectangles, then restores its own body precedence. Open utilities and closing loaders block memory recycle.

Entry points after a separately reviewed deployment/reload:

```bash
task_manager.sh
qs -c hakuspace ipc call taskManager toggle
qs -c hakuspace ipc call taskManager status
```

Sidebar → Task Manager launches the same utility. IPC also supports `open <screen>`, `openDefault` and `close`. Classic notifies unsupported and starts no collector. No new keybinding was added.

## Sampling

The loop ticks every 750 ms; slower providers run on the first eligible tick.

| Data | Requested / effective default cadence |
| --- | --- |
| CPU/core/load, memory, network, disk I/O | 750 ms |
| Process table | At least 1 s / 1.5 s |
| GPU deltas and optional sensors | At least 2 s / 2.25 s |
| CPU frequency/temperature | 3 s |
| Mount capacity | At least 5 s / 5.25 s |
| Intel existing-process FD discovery | At least 5 s / 6.75 s |
| New process discovery for Intel | Every GPU sample |

Descriptor discovery caches paths, not open FDs. Exited process entries and missing DRM clients are discarded. No Intel helper or repeated command is spawned. NVIDIA remains one bounded `nvidia-smi` query for all cards per GPU refresh, with a 2-second timeout and child cleanup on collector termination.

## CPU semantics

- `cpu.usage` and `cpu.cores`: busy/total jiffy deltas, excluding guest double counting; first sample warms up.
- `process.cpuPercent`: percent of **one logical CPU**, retained for diagnostics and a possible future per-core mode.
- `process.cpuTotalPercent`: `cpuPercent / logicalCount`; used by default process cells, accessibility text and CPU sorting.
- One logical CPU at 100% on a 12-logical-CPU host is 8.33% of total capacity, rendered as **8.3%**. If the logical count is unavailable, normalized CPU stays null rather than pretending there is one CPU; the raw diagnostic remains available. Stable identity remains `pid:startTime`, not row position.

Fixture tests deliberately give raw and normalized values different orderings to verify that sort follows the displayed metric. The live worker was approximately 98.66% raw / 8.22% normalized; btop with `proc_per_core=false` showed about 8.1%.

## CPU frequency

`frequencyMHz` was removed from this unreleased internal contract. Its consumers now use:

- `frequencyAverageMHz`: arithmetic mean of available current CPUFreq policy readings.
- `frequencyHighestMHz`: highest reading; the UI labels it **Highest**.
- `frequencyLowestMHz`: lowest reading.
- `frequencySource`: `cpufreq-scaling-cur`, `proc-cpuinfo` or `unavailable`.

The preferred source is `/sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq`, converted from kHz to MHz. If none are readable, the same statistics summarize `/proc/cpuinfo` MHz entries. Policy averages are unweighted across policies; they are not a utilization-weighted machine frequency. The kernel notes that `scaling_cur_freq` can represent a driver's last requested P-state rather than an exact instantaneous hardware clock. It is not the maximum turbo specification. [Kernel CPUFreq interface](https://docs.kernel.org/admin-guide/pm/cpufreq.html)

Both source fixtures use 400, 500, 600 and 4400 MHz and verify average 1475, highest 4400 and lowest 400. Missing values remain null.

## GPU providers and permissions

The existing schema retains `gpus[]`, `usage`, `memoryUsed`, `memoryTotal`, `temperatureC` and `available`; provider metadata/status and Intel optional fields are additive.

- **AMD — `DrmAmdProvider`:** reads `gpu_busy_percent`, VRAM sysfs and GPU-owned hwmon temperatures. Intel/NVIDIA vendor IDs are excluded. AMD fixtures remain green.
- **Intel — `IntelGpuProvider`:** reads standardized i915/xe `drm-engine-*` nanosecond counters from readable `/proc/<pid>/fdinfo/<fd>` files. It identifies devices by PCI address and deduplicates shared descriptors using `(drm-pdev, drm-client-id)`. Per-engine-class client deltas are summed, divided by engine capacity (default one), and the busiest class is reported, clamped to 100%. Temporary counter regressions retain the previous high-water mark. This follows the [kernel DRM usage-stat contract](https://docs.kernel.org/gpu/drm-usage-stats.html).
- **NVIDIA — `NvidiaSmiProvider`:** preserves its single-query multi-card CSV fallback, finite optional values, cadence and timeout/cleanup contract.
- **Unsupported:** no matching telemetry returns an empty model or a detected Intel row with an explicit unsupported-driver status. Independent provider failures do not discard healthy GPUs from another vendor.

Mixed DRM cards are sorted by numeric card ID; NVIDIA UUID rows follow in stable order. No card0 assumption is made. The UI displays all returned GPUs and retains a single primary history series.

Intel rows include `vendor`, `pciAddress`, `status`, `detail`, `scope`, `clientCount`, `inaccessibleProcesses`, `clockMHz`, `powerW` and `memoryType`. Status is one of `available`, `warmingUp`, `permissionDenied`, `unavailable`, or `unsupported`. UI text distinguishes the last three. Initial client counters warm up rather than inventing 0%.

### Acceptance host

- Intel Iris Xe / i915, PCI `0000:00:02.0`, device `8086:46A8`, DRM **card1**.
- `/sys/bus/event_source/devices/i915/type` is 14; engine PMU events exist. `perf_event_paranoid=2` limits access without a capability.
- Installed `/usr/bin/btop` has `cap_dac_read_search,cap_perfmon=ep`. Its Intel implementation uses PMU engine counters, explaining why it can read global telemetry that an ordinary Python process cannot. [btop 1.4.7 Intel collector](https://github.com/aristocratos/btop/blob/v1.4.7/src/linux/btop_collect.cpp)
- Task Manager uses the readable DRM client counters instead; observed 19 unique clients and roughly 218 inaccessible process FD directories. Its `scope` is **accessible-clients**, explicitly shown in the UI detail. It does not claim complete system-wide coverage.
- `gt_act_freq_mhz` is readable. It may return 0 while the GPU is asleep even when a preceding utilization interval contained work. The alternate `gt/gt*/rps_act_freq_mhz` path is also supported.
- GPU-owned hwmon `power1_average`/`power1_input` and `temp1_input` are used when present. This host exposes neither supported GPU hwmon sensor; `/sys/class/powercap/intel-rapl:0:1/energy_uj` (uncore) returns **PermissionError**. Power and GPU temperature remain null; btop's privileged PMU power sample was around 0.38 W. No capability or sysctl was changed and no silent root escalation was introduced.
- Iris Xe memory is shared system memory. Dedicated VRAM totals/usage remain null; the UI shows **Shared memory**.

## Process columns, signaling and audits

Header and rows instantiate `TaskManagerProcessRow`. PID width is derived from seven rendered digits using the same font, with no PID elision. Header/rows use the same five-column geometry and margins. Names elide first; CPU and RSS retain their numeric widths. The real QML harness verifies six- and seven-digit labels, no truncation, matching column positions/widths, 8.3% CPU text, and minimum/default window sizes.

Process signaling remains a separate controller. It accepts only a positive PID and TERM/KILL, pins a pidfd before reading identity, compares the selected start time, and sends the signal through that pidfd. This prevents signaling a new process that reused the PID. Gone/reused processes return `alreadyExited`; permission failures stay structured. Unsupported pidfd systems return `unavailable` rather than an unsafe fallback. TERM is an explicit action; KILL requires separate confirmation, and Delete never signals. All action tests use disposable children.

Network/disk audit required no rewrite. The only capacity-filter correction excludes efivarfs, bpf, fuse.gvfsd-fuse and fuse.portal mounts observed on the host; fixture mounts verify they are not listed as storage. Counter maps replace old interfaces/devices, new counters warm up, reset counters do not produce negative rates, and zero/nonpositive sample intervals cannot divide by zero. Mount capacity remains separate from raw I/O. Kernel diskstats sectors are 512-byte units regardless of logical device sector size; partitions, loop devices and stacked devices with backing devices are excluded from aggregate double counting.

Known network limitations remain documented rather than adding a route graph: All sums every non-loopback interface, so bridge/veth/tunnel traffic may be counted more than once. Default interface is the first alphabetically sorted active interface, not necessarily the default route. TODO for a separate task: topology-aware aggregation and default-route selection.

## Targeted validation

| Command | Result |
| --- | --- |
| `bash tests/hikai/task_manager/run.sh` | PASS: 26 Python tests, JS process/status/launcher/maintenance checks, relevant QML syntax, shell syntax and `git diff --check` |
| `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/hikai/task_manager -p test_monitor.py -v` | PASS: 18 collector tests, rerun after the unknown-logical-count boundary fix |
| `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/tempnote -p test_temp_note_overlay.py -v` | PASS: existing Temp Note lifecycle/input regression |
| `node tests/hikai/settings/test_ux.js` | PASS: shared UiState/interaction behavior |
| `PYTHONPYCACHEPREFIX=/tmp/hikai-task-manager-v11-pycache python3 -m py_compile src/core/backend/system/task_manager_monitor.py tests/hikai/task_manager/test_monitor.py` | PASS |
| `node --check src/home/.config/quickshell/hakuspace/components/taskmanager/TaskManagerLogic.js` | PASS |
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/hikai/task_manager/profile.py --hardware --output /tmp/hikai-task-manager-v11-before` | PASS: V1 baseline |
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/hikai/task_manager/profile.py --hardware --output /tmp/hikai-task-manager-v11-release` | PASS: V1.1 native profile and 20 release cycles |
| `/tmp/hikai_task_manager_v11_acceptance.py` (Python, bytecode disabled) | PASS: private native utility and simultaneous btop PTY view with a disposable CPU worker |
| `/tmp/hikai_task_manager_crosscheck.py` (Python, bytecode disabled) | PASS: independent kernel reads, CPU/RAM/loopback/disk workloads |

GPU fixtures cover Intel available/warm-up, duplicate clients, engine capacity, counter rollback, permission denial at fdinfo and proc-directory boundaries, unavailable metrics, unsupported driver, new/exited processes, descriptor disappearance, mixed-card ordering, provider failure isolation, AMD, NVIDIA and no GPU. The QML harness also retains open/close/reopen, close reversal, two-output transfer/removal, bounded history, TERM/KILL flow, Classic inactivity, actual Settings-mask pointer pass-through/body precedence, and Escape affecting only the utility holding the lease. The virtual pointer readiness handshake waits for completed Wayland round trips rather than assuming one frame is enough.

An intermediate concurrent hardware profile lost the sampled PID and was excluded. Subsequent independent profiles completed, including twenty explicit checks that each collector PID disappeared. No cause was inferred from the incomplete sample. Software/headless input probes are not hardware FPS evidence.

Targeted validation passed for the current change scope.
Full repository suite was intentionally not run.

## Performance measurements

Native Wayland, OpenGL / Mesa Intel Iris Xe (ADL GT2), eDP-1 1920 × 1080, scale 1. Both baseline and V1.1 used idle-visible workloads, 2-second warm-up/settle and 5-second sample windows with the existing Hikai live-PID sampler. Process tables contained 309 and 311 entries respectively. CPU percentages below refer to one logical CPU.

| Component | V1 RSS / PSS MiB | V1.1 RSS / PSS MiB | V1 / V1.1 CPU | V1 / V1.1 FDs |
| --- | ---: | ---: | ---: | ---: |
| baseline | 219.40 / 82.36 | 219.59 / 79.80 | 0.00% / 0.00% | 29 / 29 |
| open | 296.55 / 135.81 | 297.29 / 133.68 | 0.80% / 1.20% | 36 / 36 |
| collector | 20.23 / 11.24 | 21.21 / 12.10 | 1.80% / 3.00% | 3 / 3 |
| closed | 278.31 / 125.19 | 268.74 / 112.73 | 0.00% / 0.00% | 31 / 31 |
| settled | 278.52 / 125.39 | 269.81 / 113.71 | 0.00% / 0.00% | 30 / 30 |

First-snapshot latency was 260 ms before and 255 ms after. After V1.1's initial closed state and two batches of ten cycles: FDs **31 → 30 → 30**, threads **9 → 8 → 8**, children **0 → 0 → 0**. Every collector PID disappeared after visual release. Collector FDs stayed at 3 and threads at 1; Intel owns no persistent FD or helper process.

Intel does have a measured cost: collector RSS increased about 0.98 MiB and PSS 0.86 MiB; the final short window measured **1.8% → 3.0% of one logical CPU** (+1.2 points, about 0.1 point of this 12-logical-CPU machine). Other V1.1 short profiles measured 2.4–2.8%. A direct provider timing probe found most cached Intel samples around 3–5 ms CPU, with full discovery around 22–27 ms. Caching existing-process descriptor discovery reduced repeated scans; no allocator tuning, default software rendering or unrelated shell optimization was introduced. These short windows do not prove long-term leak absence or identical CPU conditions. The measured CPU increase is disclosed for review, not described as zero regression.

Initial Qt/driver caches remain after close. The twenty-cycle V1.1 RSS checkpoints were about 268.74 → 269.51 → 269.81 MiB; this small retained/cache variation and stable FDs are not a long-soak acceptance claim.

## Hardware comparison

The private native utility and btop ran concurrently with the same disposable CPU worker. btop used temporary configuration (`proc_per_core=false`, `freq_mode=highest`, `swap_disk=false`); user configuration was unchanged. Values below are nearby samples with different refresh windows, not synchronized equal-point assertions.

| Metric | Task Manager V1.1 | btop |
| --- | --- | --- |
| CPU total | 16.85–21.77% | About 20% |
| Busy logical core C3 | 100% | 100% |
| Load 1/5/15 | 2.81 / 3.19 / 3.10 | 2.81 / 3.19 / 3.10 |
| RAM used | 7.53 GiB / 49.16% | 7.52 GiB / 49% |
| Swap used | 893.13 MiB of approximately 12 GiB | 893 MiB of 11.9 GiB (btop's truncated formatting) |
| Test process CPU | 8.22% normalized, 98.66% raw | About 8.1% normalized |
| Intel utilization | 18.10–25.63%, accessible-client scope | About 24%, PMU global scope |
| Highest policy frequency | 3.10–3.81 GHz | About 3.8 GHz |
| Network loopback RX/TX (separate I/O run) | About 2.92 MiB/s each | About 2.88 MiB/s each |
| Disk writes (separate I/O run) | About 9.56 MiB/s physical-device throughput | Root I/O graph reacted with nonzero activity; different sample window |
| Intel power / temperature | Unavailable (sensor/permission limits above) | Power about 0.38 W |

The backend workload probe also passed: CPU delta 18.79% versus independent `/proc/stat` 18.94%; identical MemTotal 16,447,311,872 bytes; one worker about 99.05% raw and four about 393.68% combined. A 64 MiB allocation appeared at 78,520,320 bytes RSS. An 8 MiB loopback transfer produced positive matching RX/TX deltas, and a flushed/fsynced 32 MiB temporary file produced positive disk write throughput (about 74 MB/s including concurrent host I/O). These burst rates are not device-speed benchmarks. A separate simultaneous btop/native run sustained bounded loopback traffic and at most 80 MiB of temporary-file writes; both monitors reacted. Loopback is excluded from Task Manager All by design, so the backend interface entry was compared with btop explicitly set to lo. Workers were terminated/reaped and temporary files removed.

Artifacts intentionally stay outside the checkout:

- `/tmp/hikai-task-manager-v11-before/` and `/tmp/hikai-task-manager-v11-release/`: JSON sample windows, complete report and renderer/runtime log.
- `/tmp/hikai-task-manager-v11-acceptance.json`, `/tmp/hikai-task-manager-v11-acceptance.log`.
- `/tmp/hikai-task-manager-v11-btop.{txt,ansi}` and `/tmp/hikai-task-manager-crosscheck.json`.
- `/tmp/hikai-task-manager-v11-io-acceptance.json` and `/tmp/hikai-task-manager-v11-io-btop.{txt,ansi}`: simultaneous bounded disk/loopback checks.
- `/tmp/hikai-task-manager-qml.log`.

## Remaining limitations and scope

- Intel utilization only covers readable DRM clients. Protected workloads can be absent; busiest capacity-normalized engine-class usage can differ from btop's busiest individual PMU engine. No privilege change is automatic.
- A new FD opened by an already-known process can take up to roughly 6.75 seconds to be discovered; new process IDs are inspected each GPU refresh. GPU topology is rediscovered at collector startup, not continuously hotplugged.
- Intel kernels exposing only cycle counters rather than `drm-engine-*` nanoseconds are not yet decoded. Intel dedicated-VRAM accounting is not implemented; this acceptance covers a shared-memory Iris Xe.
- AMD/NVIDIA and mixed-GPU behavior are fixture-tested, not hardware-tested on this Intel-only host. Physical monitor unplug/replug, fractional-scale interaction, a 500-process visual profile and long-soak/FPS evidence remain unverified.
- Network All/default-interface limitations are described above.
- UI style, charts, animation design, process priority/nice, tree mode and arbitrary signals are outside this update.
- Repository-wide precommit, `tools/checks/repo_check.sh`, unrelated component suites and compositor-backend suites were intentionally skipped. No files were deployed, no capability/sysctl was changed, and no git commit was made.

Proposed commit title after review, including acceptance of the disclosed Intel CPU cost: `feat(hikai): complete task manager telemetry support`.
