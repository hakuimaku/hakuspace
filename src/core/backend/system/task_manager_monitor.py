#!/usr/bin/env python3
"""Stream demand-owned Linux telemetry without external Python dependencies."""
import argparse
import csv
import json
import math
import os
from pathlib import Path
import pwd
import re
import shutil
import signal
import subprocess
import time


# Kernel diskstats sectors always use 512 bytes, regardless of logical block size.
DISKSTAT_SECTOR_BYTES = 512
# Virtual filesystems do not describe user storage capacity.
PSEUDO_FS = {'proc', 'sysfs', 'tmpfs', 'devtmpfs', 'devpts', 'cgroup', 'cgroup2',
             'securityfs', 'debugfs', 'tracefs', 'pstore', 'configfs', 'mqueue',
             'hugetlbfs', 'fusectl', 'autofs', 'rpc_pipefs', 'binfmt_misc', 'nsfs', 'squashfs',
             'efivarfs', 'bpf', 'fuse.gvfsd-fuse', 'fuse.portal'}


def read_text(path):
    """Treat missing, inaccessible and undecodable kernel files as unavailable."""
    try:
        return path.read_text(errors='replace').strip()
    except OSError:
        return ''


def number(path, divisor=1):
    """Read optional sysfs numbers without inventing a zero value."""
    try:
        value = float(read_text(path)) / divisor
        return value if math.isfinite(value) else None
    except ValueError:
        return None


def percent(used, total):
    """Keep capacity percentages finite on empty devices."""
    return round(100 * used / total, 2) if total else 0


def parse_stat(text):
    """Split process names containing spaces or closing parentheses safely."""
    before, rest = text.rsplit(')', 1)
    fields = rest.split()
    return dict(pid=int(before.split('(', 1)[0]), name=before.split('(', 1)[1],
                state=fields[0], ppid=int(fields[1]), ticks=int(fields[11]) + int(fields[12]),
                threads=int(fields[17]), startTime=int(fields[19]), rssPages=int(fields[21]))


def drm_cards(sys_root):
    """Enumerate physical DRM cards in stable numeric order without assuming card0."""
    return sorted((path for path in (sys_root / 'class/drm').glob('card*')
                   if re.fullmatch(r'card\d+', path.name)), key=lambda path: int(path.name[4:]))


class DrmAmdProvider:
    """Read AMD DRM/sysfs devices and their optional hwmon sensors."""

    def __init__(self, sys_root):
        # Keep device discovery outside the fast sampling path.
        self.cards = drm_cards(sys_root)

    def sample(self):
        """Expose each supported GPU independently of missing sensors."""
        rows = []
        for card in self.cards:
            device = card / 'device'
            if read_text(device / 'vendor') not in ('', '0x1002'):
                continue
            usage = number(device / 'gpu_busy_percent')
            total = number(device / 'mem_info_vram_total')
            if usage is None and total is None:
                continue
            temperatures = [number(path, 1000) for path in device.glob('hwmon/hwmon*/temp1_input')]
            rows.append(dict(id=card.name, name=read_text(device / 'product_name') or card.name,
                             backend='drm', vendor='amd', status='available', usage=usage, memoryUsed=number(device / 'mem_info_vram_used'),
                             memoryTotal=total, temperatureC=next((v for v in temperatures if v is not None), None),
                             available=True))
        return rows


class IntelGpuProvider:
    """Read unprivileged i915/xe DRM client counters, keeping one bounded delta map."""

    def __init__(self, proc_root, sys_root):
        # Match client PCI addresses to discovered cards rather than card indices.
        self.proc = proc_root
        self.cards = [card for card in drm_cards(sys_root) if read_text(card / 'device/vendor') == '0x8086']
        self.previous, self.sample_time = {}, None
        # Cache descriptor discovery; new processes are still checked on every GPU sample.
        self.descriptors, self.inaccessible, self.discovery_due = {}, set(), 0
        self.seen_devices = set()

    def clients(self, now):
        """Deduplicate shared DRM FDs and tolerate process exit and permission races."""
        clients, denied_fds = {}, set()
        self.seen_devices = set()
        try:
            processes = [path for path in self.proc.iterdir() if path.name.isdigit()]
        except OSError as error:
            self.descriptors.clear()
            self.inaccessible.clear()
            return {}, int(isinstance(error, PermissionError))
        live = {path.name for path in processes}
        self.descriptors = {pid: paths for pid, paths in self.descriptors.items() if pid in live}
        self.inaccessible.intersection_update(live)
        discover = now >= self.discovery_due
        if discover:
            self.discovery_due = now + 5
            self.inaccessible.clear()
        for process in processes:
            if discover or process.name not in self.descriptors:
                paths = []
                try:
                    descriptors = list((process / 'fd').iterdir())
                except PermissionError:
                    self.inaccessible.add(process.name)
                    descriptors = []
                except OSError:
                    descriptors = []
                for descriptor in descriptors:
                    try:
                        # Filter non-DRM descriptors before reading fdinfo files.
                        if str(descriptor.readlink()).startswith('/dev/dri/'):
                            paths.append(descriptor)
                    except PermissionError:
                        self.inaccessible.add(process.name)
                        break
                    except OSError:
                        continue
                self.descriptors[process.name] = paths
            for descriptor in self.descriptors[process.name]:
                try:
                    text = (process / 'fdinfo' / descriptor.name).read_text(errors='replace')
                except PermissionError:
                    denied_fds.add(process.name)
                    continue
                except OSError:
                    continue
                fields = dict(line.split(':', 1) for line in text.splitlines() if ':' in line)
                fields = {key: value.strip() for key, value in fields.items()}
                if fields.get('drm-driver') not in ('i915', 'xe') or not fields.get('drm-pdev') or not fields.get('drm-client-id'):
                    continue
                self.seen_devices.add(fields['drm-pdev'])
                key = fields['drm-pdev'], fields['drm-client-id']
                if key in clients:
                    continue
                engines, capacities = {}, {}
                for name, value in fields.items():
                    if name.startswith('drm-engine-capacity-') and value.isdigit() and int(value) > 0:
                        capacities[name.removeprefix('drm-engine-capacity-')] = int(value)
                    elif name.startswith('drm-engine-') and re.fullmatch(r'\d+ ns', value):
                        engines[name.removeprefix('drm-engine-')] = int(value.split()[0])
                if engines:
                    clients[key] = engines, capacities
        return clients, len(self.inaccessible | denied_fds)

    def sample(self, now):
        """Report busiest engine-class utilization across accessible, unique clients."""
        if not self.cards:
            return []
        clients, inaccessible = self.clients(now)
        elapsed = now - self.sample_time if self.sample_time is not None else 0
        totals, current = {}, {}
        for key, (engines, capacities) in clients.items():
            previous = self.previous.get(key, {})
            current[key] = {}
            for engine, counter in engines.items():
                # DRM counters may temporarily move backwards; retain the previous high-water mark.
                counter = max(counter, previous.get(engine, counter))
                current[key][engine] = counter
                if engine in previous and elapsed > 0:
                    bucket = totals.setdefault(key[0], {})
                    bucket[engine] = bucket.get(engine, 0) + (counter - previous[engine]) / capacities.get(engine, 1)
        self.previous, self.sample_time = current, now
        rows = []
        for card in self.cards:
            metadata = dict(line.split('=', 1) for line in read_text(card / 'device/uevent').splitlines() if '=' in line)
            pci = metadata.get('PCI_SLOT_NAME', card.resolve().parent.parent.name)
            engine_totals = totals.get(pci, {})
            usage = min(100, max(engine_totals.values()) / (elapsed * 1e9) * 100) if engine_totals else None
            has_clients = any(key[0] == pci for key in clients)
            status = 'available' if usage is not None else ('warmingUp' if has_clients else ('permissionDenied' if inaccessible and pci not in self.seen_devices else 'unavailable'))
            if metadata.get('DRIVER', 'i915') not in ('i915', 'xe'):
                status = 'unsupported'
                usage = None
            # Read only sensors owned by this GPU; shared system RAM is not dedicated VRAM.
            clocks = [card / 'gt_act_freq_mhz'] + sorted(card.glob('gt/gt*/rps_act_freq_mhz'))
            clock = next((value for path in clocks if (value := number(path)) is not None), None)
            hwmons = sorted((card / 'device/hwmon').glob('hwmon*'))
            temperature = next((value for hwmon in hwmons if (value := number(hwmon / 'temp1_input', 1000)) is not None), None)
            power = next((value for hwmon in hwmons for name in ('power1_average', 'power1_input')
                          if (value := number(hwmon / name, 1e6)) is not None), None)
            detail = 'Accessible DRM clients only'
            if status == 'unsupported':
                detail = 'Intel driver does not expose supported i915/xe DRM counters'
            elif status == 'permissionDenied':
                detail = 'Cannot read DRM client counters in /proc/<pid>/fdinfo'
            elif status == 'unavailable':
                detail = 'No readable i915/xe drm-engine counters in /proc/<pid>/fdinfo'
            rows.append(dict(id=card.name, pciAddress=pci, name=read_text(card / 'device/product_name')
                             or 'Intel GPU ' + metadata.get('PCI_ID', pci), vendor='intel', backend='intel-drm-fdinfo',
                             usage=usage, clockMHz=clock, powerW=power, temperatureC=temperature,
                             memoryUsed=None, memoryTotal=None, memoryType='shared', available=usage is not None,
                             status=status, detail=detail, scope='accessible-clients', inaccessibleProcesses=inaccessible,
                             clientCount=sum(key[0] == pci for key in clients)))
        return rows


class NvidiaSmiProvider:
    """Collect all NVIDIA cards with one bounded invocation."""

    def __init__(self, executable):
        # Accept an explicit executable for fixtures and nonstandard installations.
        self.executable = executable

    def sample(self):
        """Degrade driver errors and unsupported columns to optional data."""
        if not self.executable:
            return []
        child = None
        try:
            child = subprocess.Popen([self.executable,
                '--query-gpu=uuid,name,utilization.gpu,memory.used,memory.total,temperature.gpu',
                '--format=csv,noheader,nounits'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            output, _ = child.communicate(timeout=2)
            if child.returncode:
                return []
        except (OSError, subprocess.SubprocessError):
            return []
        finally:
            # Collector termination also reaps an in-flight driver query.
            if child is not None:
                if child.poll() is None:
                    child.kill()
                child.wait()
        rows = []
        for fields in csv.reader(output.splitlines()):
            if len(fields) != 6:
                continue
            values = []
            for field in fields[2:]:
                try:
                    value = float(field.strip())
                    values.append(value if math.isfinite(value) else None)
                except ValueError:
                    values.append(None)
            usage, used, total, temperature = values
            rows.append(dict(id=fields[0].strip(), name=fields[1].strip(), backend='nvidia-smi', vendor='nvidia', status='available',
                             usage=usage, memoryUsed=None if used is None else int(used * 1024**2),
                             memoryTotal=None if total is None else int(total * 1024**2),
                             temperatureC=temperature, available=True))
        return rows


class UnsupportedGpuProvider:
    """Represent unsupported hardware without polling external commands."""

    def sample(self):
        """Return an empty multi-GPU model."""
        return []


class Monitor:
    """Keep bounded counter deltas and cache slow providers for one session."""

    def __init__(self, proc_root='/proc', sys_root='/sys', mount_root='/', nvidia_smi=None):
        # Route filesystem reads through injectable roots.
        self.proc, self.sys, self.mount = Path(proc_root), Path(sys_root), Path(mount_root)
        # Convert kernel time and RSS units once per collector lifetime.
        self.hz, self.page_size = os.sysconf('SC_CLK_TCK'), os.sysconf('SC_PAGE_SIZE')
        # Store only the most recent sample for each live identity.
        self.previous, self.cached, self.due, self.users = {}, {}, {}, {}
        self.seq = 0
        executable = shutil.which('nvidia-smi') if nvidia_smi is None else nvidia_smi
        self.drm = DrmAmdProvider(self.sys)
        self.intel = IntelGpuProvider(self.proc, self.sys)
        self.nvidia = NvidiaSmiProvider(executable) if executable else UnsupportedGpuProvider()

    def rates(self, group, current, now, scale=1):
        """Reset new, removed and rolled-back counters instead of reporting spikes."""
        old_time, old = self.previous.get(group, (now, {}))
        self.previous[group] = now, current
        elapsed = now - old_time
        return {key: [max(0, value - previous) * scale / elapsed
                      if value >= previous else 0 for value, previous in zip(values, old[key])]
                if elapsed > 0 and key in old else [None] * len(values)
                for key, values in current.items()}

    def cpu(self, now):
        """Compute aggregate and per-core busy fractions from jiffy deltas."""
        counters = {}
        for line in read_text(self.proc / 'stat').splitlines():
            fields = line.split()
            if not fields or not re.fullmatch(r'cpu\d*', fields[0]):
                continue
            values = [int(value) for value in fields[1:9]]
            if len(values) < 4:
                continue
            counters[fields[0]] = [sum(values), values[3] + (values[4] if len(values) > 4 else 0)]
        deltas = self.rates('cpu', counters, now)
        usage = {key: round(max(0, min(100, 100 * (total - idle) / total)), 2)
                 if total and idle is not None else None for key, (total, idle) in deltas.items()}
        cores = [usage[key] for key in sorted(usage, key=lambda key: int(key[3:] or '-1')) if key != 'cpu']
        load = [float(value) for value in read_text(self.proc / 'loadavg').split()[:3]]
        if not all(math.isfinite(value) for value in load):
            load = []
        return dict(available='cpu' in counters, warmingUp=usage.get('cpu') is None,
                    usage=usage.get('cpu'), cores=cores, logicalCount=len(cores), load=load)

    def sensors(self):
        """Read CPU frequency and a CPU-labelled temperature at a slower cadence."""
        frequencies = [value for path in (self.sys / 'devices/system/cpu/cpufreq').glob('policy*/scaling_cur_freq')
                       if (value := number(path, 1000)) is not None and value > 0]
        frequency_source = 'cpufreq-scaling-cur'
        if not frequencies:
            frequencies = [float(value) for value in re.findall(r'cpu MHz\s*:\s*([\d.]+)', read_text(self.proc / 'cpuinfo'))]
            frequency_source = 'proc-cpuinfo' if frequencies else 'unavailable'
        temperature = None
        for hwmon in sorted((self.sys / 'class/hwmon').glob('hwmon*')):
            if read_text(hwmon / 'name') not in ('coretemp', 'k10temp', 'zenpower', 'cpu_thermal'):
                continue
            temperature = number(hwmon / 'temp1_input', 1000)
            if temperature is not None:
                break
        if temperature is None:
            for zone in sorted((self.sys / 'class/thermal').glob('thermal_zone*')):
                if any(label in read_text(zone / 'type').lower() for label in ('cpu', 'x86_pkg', 'soc')):
                    temperature = number(zone / 'temp', 1000)
                    if temperature is not None:
                        break
        return dict(frequencySource=frequency_source, frequencyAverageMHz=sum(frequencies) / len(frequencies) if frequencies else None,
                    frequencyHighestMHz=max(frequencies) if frequencies else None,
                    frequencyLowestMHz=min(frequencies) if frequencies else None,
                    temperatureC=temperature)

    def memory(self):
        """Expose memory and swap byte counts with reclaimable cache."""
        values = {key: int(value) * 1024 for key, value in
                  re.findall(r'^(\w+):\s+(\d+)', read_text(self.proc / 'meminfo'), re.M)}
        total, available = values.get('MemTotal', 0), values.get('MemAvailable', values.get('MemFree', 0))
        swap = values.get('SwapTotal', 0)
        used = max(0, total - available)
        return dict(available=total > 0, total=total, used=used, availableBytes=available,
                    cache=values.get('Cached', 0) + values.get('SReclaimable', 0),
                    buffers=values.get('Buffers', 0), percent=percent(used, total) if total else None,
                    swapTotal=swap, swapUsed=max(0, swap - values.get('SwapFree', 0)))

    def network(self, now):
        """Preserve interface totals and derive rates only across matching counters."""
        counters = {}
        for line in read_text(self.proc / 'net/dev').splitlines():
            if ':' not in line:
                continue
            name, data = line.split(':', 1)
            fields = data.split()
            if len(fields) >= 16:
                counters[name.strip()] = [int(fields[0]), int(fields[8])]
        rates = self.rates('network', counters, now)
        rows = [dict(name=name, rxBytes=values[0], txBytes=values[1], rxBps=rates[name][0],
                     txBps=rates[name][1], loopback=name == 'lo',
                     active=read_text(self.sys / 'class/net' / name / 'operstate') == 'up')
                for name, values in sorted(counters.items())]
        public = [row for row in rows if not row['loopback']]
        totals = {key: sum(row[key] or 0 for row in public) if any(row[key] is not None for row in public) else None
                  for key in ('rxBytes', 'txBytes', 'rxBps', 'txBps')}
        return dict(available=bool(rows), interfaces=rows, all=totals,
                    defaultInterface=next((row['name'] for row in public if row['active']), 'All'))

    def disk_io(self, now):
        """Count whole block devices once, excluding partitions and loop devices."""
        counters = {}
        for line in read_text(self.proc / 'diskstats').splitlines():
            fields = line.split()
            if len(fields) < 14:
                continue
            name = fields[2]
            device = self.sys / 'class/block' / name
            if name.startswith(('loop', 'ram')) or (device / 'partition').exists():
                continue
            # /sys/block contains whole devices; /sys/class/block also contains partitions.
            if not (self.sys / 'block' / name).exists():
                continue
            # Count backing devices instead of counting their mapped I/O a second time.
            if any((self.sys / 'block' / name / 'slaves').glob('*')):
                continue
            counters[name] = [int(fields[5]), int(fields[9])]
        rates = self.rates('disk', counters, now, DISKSTAT_SECTOR_BYTES)
        rows = [dict(name=name, readBps=values[0], writeBps=values[1], sectorBytes=DISKSTAT_SECTOR_BYTES,
                     source='proc-diskstats-512-byte-sectors') for name, values in sorted(rates.items())]
        return dict(available=bool(rows), devices=rows,
                    readBps=sum(row['readBps'] or 0 for row in rows) if any(row['readBps'] is not None for row in rows) else None,
                    writeBps=sum(row['writeBps'] or 0 for row in rows) if any(row['writeBps'] is not None for row in rows) else None)

    def mounts(self):
        """Keep storage capacity separate from block-device throughput."""
        rows, seen = [], set()
        for line in read_text(self.proc / 'self/mounts').splitlines():
            fields = line.split()
            if len(fields) < 3 or fields[2] in PSEUDO_FS or fields[0].startswith('/dev/loop'):
                continue
            source, target, fs_type = fields[:3]
            target = re.sub(r'\\([0-7]{3})', lambda match: chr(int(match[1], 8)), target)
            if target in seen:
                continue
            seen.add(target)
            try:
                info = os.statvfs(self.mount / target.lstrip('/'))
            except OSError:
                continue
            total, free, available = info.f_blocks * info.f_frsize, info.f_bfree * info.f_frsize, info.f_bavail * info.f_frsize
            used = total - free
            rows.append(dict(mount=target, source=source, filesystem=fs_type, total=total,
                             used=used, available=available, percent=percent(used, used + available)))
        return rows

    def processes(self, now, memory_total, logical_count):
        """Sample processes by PID and start time, tolerating exit and permission races."""
        old_time, old = self.previous.get('processes', (now, {}))
        elapsed, counters, rows = now - old_time, {}, []
        uptime = float((read_text(self.proc / 'uptime') or '0').split()[0])
        for path in self.proc.iterdir():
            if not path.name.isdigit():
                continue
            try:
                process = parse_stat((path / 'stat').read_text())
                status = (path / 'status').read_text()
                uid = int(re.search(r'^Uid:\s+(\d+)', status, re.M)[1])
                if uid not in self.users:
                    try:
                        self.users[uid] = pwd.getpwuid(uid).pw_name
                    except KeyError:
                        self.users[uid] = str(uid)
                cmdline = (path / 'cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace').strip()
                # Verify identity after the multi-file read to discard a reused PID.
                if parse_stat((path / 'stat').read_text())['startTime'] != process['startTime']:
                    continue
            except (OSError, ValueError, IndexError, TypeError):
                continue
            key = f"{process['pid']}:{process['startTime']}"
            counters[key] = process['ticks']
            cpu = max(0, (process['ticks'] - old[key]) / self.hz / elapsed * 100) if key in old and elapsed > 0 else None
            rss = max(0, process.pop('rssPages') * self.page_size)
            process.update(key=key, cmdline=cmdline, user=self.users[uid], uid=uid, rss=rss,
                           cpuPercent=cpu, cpuTotalPercent=cpu / logical_count if cpu is not None and logical_count > 0 else None,
                           memoryPercent=percent(rss, memory_total) if memory_total else None, runtimeSeconds=max(0, uptime - process['startTime'] / self.hz))
            process.pop('ticks')
            rows.append(process)
        self.previous['processes'] = now, counters
        return rows

    def gpus(self, now):
        """Keep mixed-vendor devices in physical card order, then NVIDIA UUID order."""
        rows = []
        for callback in (self.drm.sample, lambda: self.intel.sample(now), self.nvidia.sample):
            try:
                rows.extend(callback())
            except (OSError, ValueError, csv.Error):
                continue
        return sorted(rows, key=lambda row: (0, int(row['id'][4:]))
                      if re.fullmatch(r'card\d+', row['id']) else (1, row['id']))

    def slow(self, key, now, interval, callback):
        """Cache independent slow providers without hiding failures in other groups."""
        if now >= self.due.get(key, 0):
            self.cached[key] = callback()
            self.due[key] = now + interval
        return self.cached[key]

    def sample(self, now=None):
        """Emit schema 1 even when an individual kernel provider is unavailable."""
        now = time.monotonic() if now is None else now
        self.seq += 1
        snapshot = dict(schema=1, seq=self.seq, monotonicMs=round(now * 1000), errors={})
        providers = {
            'cpu': lambda: self.cpu(now) | self.slow('sensors', now, 3, self.sensors),
            'memory': self.memory,
            'gpus': lambda: self.slow('gpus', now, 2, lambda: self.gpus(now)),
            'disks': lambda: self.disk_io(now) | {'mounts': self.slow('mounts', now, 5, self.mounts)},
            'network': lambda: self.network(now),
            'processes': lambda: self.slow('processes', now, 1, lambda: self.processes(
                now, snapshot.get('memory', {}).get('total', 0), snapshot.get('cpu', {}).get('logicalCount', 0))),
        }
        for name, callback in providers.items():
            try:
                snapshot[name] = callback()
            except (OSError, ValueError, IndexError, TypeError) as error:
                snapshot[name] = [] if name in ('gpus', 'processes') else {'available': False}
                snapshot['errors'][name] = type(error).__name__
        snapshot['processMonotonicMs'] = round(self.previous.get('processes', (0, {}))[0] * 1000)
        snapshot['capabilities'] = dict(gpu=any(row['available'] for row in snapshot['gpus']),
            gpuTemperature=any(row['temperatureC'] is not None for row in snapshot['gpus']),
            diskIo=snapshot['disks'].get('available', False), processControl=hasattr(os, 'kill'))
        return snapshot


def main():
    """Run finite or streaming sampling, stopping cleanly on SIGTERM or a closed pipe."""
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--stream', action='store_true')
    mode.add_argument('--once', action='store_true')
    parser.add_argument('--pretty', action='store_true')
    parser.add_argument('--interval-ms', type=int, default=750)
    parser.add_argument('--proc-root', default='/proc')
    parser.add_argument('--sys-root', default='/sys')
    parser.add_argument('--mount-root', default='/')
    parser.add_argument('--nvidia-smi', default=None)
    args = parser.parse_args()
    if args.interval_ms < 100 or (args.stream and args.pretty):
        parser.error('interval must be at least 100 ms; pretty output requires --once')
    monitor = Monitor(args.proc_root, args.sys_root, args.mount_root, args.nvidia_smi)
    # Interrupt sleep immediately so UI destruction never leaves an idle collector.
    signal.signal(signal.SIGTERM, lambda *_: exit(0))
    try:
        while True:
            start = time.monotonic()
            print(json.dumps(monitor.sample(start), indent=2 if args.pretty else None, allow_nan=False), flush=True)
            if not args.stream:
                break
            time.sleep(max(0, args.interval_ms / 1000 - (time.monotonic() - start)))
    except (BrokenPipeError, KeyboardInterrupt):
        pass


if __name__ == '__main__':
    main()
