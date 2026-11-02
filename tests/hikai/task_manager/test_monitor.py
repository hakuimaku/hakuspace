#!/usr/bin/env python3
"""Verify telemetry against deterministic proc/sys fixtures."""
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

# Load the production collector without changing installed modules.
ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'src/core/backend/system/task_manager_monitor.py'
spec = importlib.util.spec_from_file_location('task_manager_monitor', SOURCE)
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)
sys.modules['task_manager_monitor'] = monitor


class MonitorTest(unittest.TestCase):
    """Create each kernel fixture in a private directory."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.proc, self.sys, self.mount = [self.root / name for name in ('proc', 'sys', 'mount')]
        for path in (self.proc, self.sys, self.mount):
            path.mkdir()
        self.write('proc/stat', 'cpu 100 0 100 800 0 0 0 0 0 0\ncpu0 50 0 50 400\ncpu1 50 0 50 400\n')
        self.write('proc/meminfo', 'MemTotal: 10000 kB\nMemAvailable: 6000 kB\nCached: 1000 kB\nBuffers: 100 kB\nSReclaimable: 200 kB\nSwapTotal: 2000 kB\nSwapFree: 1500 kB\n')
        self.write('proc/loadavg', '1.2 0.9 0.7 1/30 1')
        self.write('proc/uptime', '1000 800')
        self.write('proc/cpuinfo', 'cpu MHz : 3200\ncpu MHz : 3600')
        self.write('proc/net/dev', 'eth0: 1000 0 0 0 0 0 0 0 2000 0 0 0 0 0 0 0\nlo: 500 0 0 0 0 0 0 0 500 0 0 0 0 0 0 0')
        self.write('sys/class/net/eth0/operstate', 'up')
        self.write('proc/diskstats', '8 0 sda 1 0 100 0 1 0 200 0 0 0 0\n8 1 sda1 1 0 100 0 1 0 200 0 0 0 0\n7 0 loop0 1 0 100 0 1 0 200 0 0 0 0')
        (self.sys / 'block/sda').mkdir(parents=True)
        self.write('sys/class/block/sda1/partition', '1')
        self.write('proc/self/mounts', '/dev/sda1 / ext4 rw 0 0\nproc /proc proc rw 0 0\n/dev/loop0 /snap ext4 rw 0 0')
        self.process(12, 100, 10)
        self.collector = monitor.Monitor(self.proc, self.sys, self.mount, '')

    def write(self, path, value):
        """Write only fixture paths beneath the disposable root."""
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(value)
        return target

    def process(self, pid, start, ticks):
        """Build stat fields including a name with parentheses and spaces."""
        fields = ['S', '1'] + ['0'] * 9 + [str(ticks), '0', '0', '0', '0', '0', '2', '0', str(start), '4096', '10']
        self.write(f'proc/{pid}/stat', f'{pid} (test ) process) ' + ' '.join(fields))
        self.write(f'proc/{pid}/status', f'Uid:\t{os.getuid()}\t{os.getuid()}\n')
        self.write(f'proc/{pid}/cmdline', 'test\0--flag\0')

    def test_schema_warmup_memory_mount_gpu(self):
        """The first sample exposes capacities but never fabricated CPU rates."""
        sample = self.collector.sample(10)
        self.assertEqual(sample['schema'], 1)
        self.assertTrue(set(('cpu', 'memory', 'gpus', 'disks', 'network', 'processes', 'capabilities')) <= sample.keys())
        self.assertEqual(sample['errors'], {})
        self.assertTrue(sample['cpu']['warmingUp'])
        self.assertIsNone(sample['cpu']['usage'])
        self.assertIsNone(sample['network']['all']['rxBps'])
        self.assertIsNone(sample['disks']['readBps'])
        self.assertEqual(sample['cpu']['cores'], [None, None])
        self.assertEqual(sample['cpu']['frequencyAverageMHz'], 3400)
        self.assertEqual(sample['memory']['used'], 4000 * 1024)
        self.assertEqual(sample['memory']['cache'], 1200 * 1024)
        self.assertEqual(sample['memory']['swapUsed'], 500 * 1024)
        self.assertEqual(sample['memory']['percent'], 40)
        for filesystem in ('efivarfs', 'bpf', 'fuse.gvfsd-fuse', 'fuse.portal'):
            (self.mount / filesystem).mkdir()
            with (self.proc / 'self/mounts').open('a') as mounts:
                mounts.write(f'\n{filesystem} /{filesystem} {filesystem} rw 0 0')
        self.assertEqual(len(self.collector.mounts()), 1)
        self.assertEqual(len(sample['disks']['mounts']), 1)
        self.assertEqual(sample['disks']['mounts'][0]['total'], os.statvfs(self.mount).f_blocks * os.statvfs(self.mount).f_frsize)
        self.assertEqual(sample['gpus'], [])
        self.assertFalse(sample['capabilities']['gpu'])
        self.assertEqual(sample['processes'][0]['name'], 'test ) process')
        json.dumps(sample, allow_nan=False)

    def test_twelve_core_cpu_semantics_and_frequency(self):
        """One busy logical CPU is 8.33 percent of a twelve-core host."""
        self.write('proc/stat', 'cpu 100 0 100 800\n' + ''.join(f'cpu{i} 10 0 10 80\n' for i in range(12)))
        self.write('proc/cpuinfo', '\n'.join(f'cpu MHz : {value}' for value in (400, 500, 600, 4400)))
        self.collector.sample(10)
        self.process(12, 100, 10 + self.collector.hz * 2)
        sample = self.collector.sample(12)
        self.assertEqual(sample['cpu']['logicalCount'], 12)
        self.assertEqual(sample['processes'][0]['cpuPercent'], 100)
        self.assertAlmostEqual(sample['processes'][0]['cpuTotalPercent'], 100 / 12)
        self.assertEqual(sample['cpu']['frequencyAverageMHz'], 1475)
        self.assertEqual(sample['cpu']['frequencyHighestMHz'], 4400)
        self.assertEqual(sample['cpu']['frequencyLowestMHz'], 400)
        self.assertNotIn('frequencyMHz', sample['cpu'])

    def test_cpufreq_policy_semantics(self):
        """Prefer reported current policy frequencies, converting kHz to MHz."""
        for index, value in enumerate((400, 500, 600, 4400)):
            self.write(f'sys/devices/system/cpu/cpufreq/policy{index}/scaling_cur_freq', str(value * 1000))
        cpu = self.collector.sample(10)['cpu']
        self.assertEqual(cpu['frequencySource'], 'cpufreq-scaling-cur')
        self.assertEqual(cpu['frequencyAverageMHz'], 1475)
        self.assertEqual(cpu['frequencyHighestMHz'], 4400)
        self.assertEqual(cpu['frequencyLowestMHz'], 400)

    def test_cpu_network_disk_process_deltas(self):
        """Rates use elapsed seconds; process CPU is one-core percent and can exceed 100."""
        self.collector.sample(10)
        self.write('proc/stat', 'cpu 150 0 150 900 0 0 0 0\ncpu0 100 0 50 450\ncpu1 50 0 100 450')
        self.write('proc/net/dev', 'eth0: 3000 0 0 0 0 0 0 0 6000 0 0 0 0 0 0 0')
        self.write('sys/block/dm-0/slaves/sda', '')
        self.write('proc/diskstats', '8 0 sda 1 0 104 0 1 0 208 0 0 0 0\n253 0 dm-0 1 0 104 0 1 0 208 0 0 0 0')
        self.process(12, 100, 10 + self.collector.hz * 3)
        sample = self.collector.sample(12)
        self.assertEqual(sample['cpu']['usage'], 50)
        self.assertEqual(sample['cpu']['cores'], [50, 50])
        self.assertEqual(sample['network']['all']['rxBps'], 1000)
        self.assertEqual(sample['network']['all']['txBps'], 2000)
        self.assertEqual(sample['network']['defaultInterface'], 'eth0')
        self.assertEqual(sample['disks']['readBps'], 1024)
        self.assertEqual(sample['disks']['writeBps'], 2048)
        self.assertEqual(len(sample['disks']['devices']), 1)
        self.assertEqual(sample['processes'][0]['cpuPercent'], 150)
        self.assertEqual(sample['processes'][0]['cpuTotalPercent'], 75)

    def test_interface_and_pid_reuse(self):
        """New identities warm up, rolled-back counters reset and old identities disappear."""
        self.collector.sample(10)
        self.write('proc/net/dev', 'wlan0: 900 0 0 0 0 0 0 0 700 0 0 0 0 0 0 0')
        self.process(12, 200, 99999)
        sample = self.collector.sample(12)
        self.assertEqual([row['name'] for row in sample['network']['interfaces']], ['wlan0'])
        self.assertIsNone(sample['network']['interfaces'][0]['rxBps'])
        self.assertIsNone(sample['processes'][0]['cpuPercent'])
        self.assertEqual(set(self.collector.previous['processes'][1]), {'12:200'})
        self.write('proc/net/dev', 'wlan0: 1 0 0 0 0 0 0 0 2 0 0 0 0 0 0 0')
        self.assertEqual(self.collector.sample(14)['network']['all']['rxBps'], 0)

    def test_process_races_and_permissions(self):
        """A process disappearing or refusing a read cannot discard other telemetry."""
        original = Path.read_text
        for index, exception in enumerate((FileNotFoundError, PermissionError)):
            with self.subTest(exception=exception):
                def read(path, *args, **kwargs):
                    if path == self.proc / '12/status':
                        raise exception()
                    return original(path, *args, **kwargs)
                with patch.object(Path, 'read_text', read):
                    sample = self.collector.sample(10 + index * 2)
                self.assertEqual(sample['processes'], [])
                self.assertTrue(sample['memory']['available'])
        self.assertEqual(self.collector.previous['processes'][1], {})

    def test_drm_and_nvidia(self):
        """DRM data and a single multi-GPU NVIDIA invocation preserve optional fields."""
        self.write('sys/class/drm/card0/device/gpu_busy_percent', '52')
        self.write('sys/class/drm/card0/device/mem_info_vram_total', '8589934592')
        self.write('sys/class/drm/card0/device/mem_info_vram_used', '2147483648')
        self.write('sys/class/drm/card0/device/hwmon/hwmon0/temp1_input', '63000')
        provider = monitor.DrmAmdProvider(self.sys)
        self.assertEqual(provider.sample()[0]['temperatureC'], 63)
        self.assertEqual(provider.sample()[0]['usage'], 52)
        executable = self.write('nvidia-smi', '#!/bin/sh\nprintf \'GPU-1, Example, 40, 100, 1000, 60\\nGPU-2, Other, N/A, N/A, N/A, N/A\\n\'\n')
        executable.chmod(0o755)
        rows = monitor.NvidiaSmiProvider(str(executable)).sample()
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]['memoryUsed'], 100 * 1024**2)
        self.assertIsNone(rows[1]['usage'])
        self.assertEqual(monitor.NvidiaSmiProvider('/missing').sample(), [])

    def intel_card(self, index=2, pci='0000:00:02.0'):
        """Create a card with sensors without dedicated VRAM."""
        self.write(f'sys/class/drm/card{index}/device/vendor', '0x8086')
        self.write(f'sys/class/drm/card{index}/device/uevent', f'DRIVER=i915\nPCI_SLOT_NAME={pci}\nPCI_ID=8086:46A8')
        self.write(f'sys/class/drm/card{index}/gt_act_freq_mhz', '1200')
        self.write(f'sys/class/drm/card{index}/device/hwmon/hwmon0/power1_average', '590000')
        self.write(f'sys/class/drm/card{index}/device/hwmon/hwmon0/temp1_input', '40000')

    def intel_client(self, client=7, counter=0, pid=12, fd=8, pci='0000:00:02.0', engine='render', capacity=1):
        """Model a DRM FD and its standardized nanosecond client counters."""
        if not (self.proc / str(pid) / 'stat').exists():
            self.process(pid, 100, 0)
        descriptor = self.root / f'proc/{pid}/fd/{fd}'
        descriptor.parent.mkdir(parents=True, exist_ok=True)
        if not descriptor.is_symlink():
            descriptor.symlink_to('/dev/dri/renderD128')
        return self.write(f'proc/{pid}/fdinfo/{fd}', f'drm-driver: i915\ndrm-pdev: {pci}\ndrm-client-id: {client}\n'
            f'drm-engine-{engine}: {counter} ns\ndrm-engine-capacity-{engine}: {capacity}\n')

    def test_intel_available_and_shared_client(self):
        """Deduplicate shared FDs and sum independent clients within an engine class."""
        self.intel_card()
        self.intel_client(counter=1_000_000_000)
        self.intel_client(counter=1_000_000_000, fd=9)
        self.intel_client(client=8, counter=0, fd=10)
        provider = monitor.IntelGpuProvider(self.proc, self.sys)
        self.assertEqual(provider.sample(10)[0]['status'], 'warmingUp')
        self.intel_client(counter=1_400_000_000)
        self.intel_client(counter=1_400_000_000, fd=9)
        self.intel_client(client=8, counter=200_000_000, fd=10)
        row = provider.sample(12)[0]
        self.assertEqual(row['usage'], 30)
        self.assertEqual(row['status'], 'available')
        self.assertEqual(row['clientCount'], 2)
        self.assertEqual(row['clockMHz'], 1200)
        self.assertEqual(row['powerW'], 0.59)
        self.assertEqual(row['temperatureC'], 40)
        self.assertEqual(row['memoryType'], 'shared')
        self.assertIsNone(row['memoryTotal'])
        self.assertIsNone(row['memoryUsed'])
        self.intel_client(counter=1_100_000_000)
        self.intel_client(counter=1_100_000_000, fd=9)
        self.assertEqual(provider.sample(14)[0]['usage'], 0)
        self.intel_client(counter=1_600_000_000)
        self.intel_client(counter=1_600_000_000, fd=9)
        self.assertEqual(provider.sample(16)[0]['usage'], 10)

    def test_intel_permissions_and_missing_metric(self):
        """Report access failures separately from absent engine counters."""
        self.intel_card()
        fdinfo = self.intel_client()
        provider = monitor.IntelGpuProvider(self.proc, self.sys)
        original = Path.read_text
        def read(path, *args, **kwargs):
            if path == fdinfo:
                raise PermissionError()
            return original(path, *args, **kwargs)
        with patch.object(Path, 'read_text', read):
            row = provider.sample(10)[0]
        self.assertEqual(row['status'], 'permissionDenied')
        self.assertFalse(row['available'])
        self.assertIn('/proc/', row['detail'])
        fdinfo.write_text('drm-driver: i915\ndrm-pdev: 0000:00:02.0\ndrm-client-id: 7\n')
        row = provider.sample(12)[0]
        self.assertEqual(row['status'], 'unavailable')
        self.assertIsNone(row['usage'])
        self.assertEqual(provider.previous, {})

    def test_intel_proc_permission_and_unsupported_driver(self):
        """Keep a detected card visible when proc access or the DRM driver is unsupported."""
        self.intel_card()
        provider = monitor.IntelGpuProvider(self.proc, self.sys)
        original = Path.iterdir
        def iterdir(path):
            if path == self.proc:
                raise PermissionError()
            return original(path)
        with patch.object(Path, 'iterdir', iterdir):
            row = provider.sample(10)[0]
        self.assertEqual(row['status'], 'permissionDenied')
        self.assertFalse(row['available'])
        self.write('sys/class/drm/card2/device/uevent', 'DRIVER=other\nPCI_SLOT_NAME=0000:00:02.0')
        self.assertEqual(provider.sample(12)[0]['status'], 'unsupported')

    def test_intel_identity_permission(self):
        """Unreadable process identity stays permission-denied rather than using a stale cache."""
        self.intel_card()
        self.intel_client()
        provider = monitor.IntelGpuProvider(self.proc, self.sys)
        provider.sample(10)
        original = Path.read_text
        def read(path, *args, **kwargs):
            if path == self.proc / '12/stat':
                raise PermissionError()
            return original(path, *args, **kwargs)
        with patch.object(Path, 'read_text', read):
            row = provider.sample(12)[0]
        self.assertEqual(row['status'], 'permissionDenied')
        self.assertEqual(provider.descriptors, {})

    def test_intel_capacity_exit_and_multi_gpu(self):
        """Keep capacity, vanished clients and mixed-card ordering deterministic."""
        self.intel_card(2)
        self.intel_card(3, '0000:03:00.0')
        fdinfo = self.intel_client(engine='video', capacity=2)
        self.write('sys/class/drm/card10/device/vendor', '0x1002')
        self.write('sys/class/drm/card10/device/gpu_busy_percent', '52')
        collector = monitor.Monitor(self.proc, self.sys, self.mount, '')
        self.assertEqual([row['id'] for row in collector.sample(10)['gpus']], ['card2', 'card3', 'card10'])
        self.intel_client(counter=2_000_000_000, engine='video', capacity=2)
        rows = collector.sample(12.5)['gpus']
        self.assertEqual(rows[0]['usage'], 40)
        self.assertEqual(rows[1]['status'], 'unavailable')
        self.assertEqual(rows[2]['vendor'], 'amd')
        self.assertEqual(rows[2]['usage'], 52)
        fdinfo.unlink()
        self.assertEqual(collector.sample(15)['gpus'][0]['status'], 'unavailable')
        self.assertEqual(collector.intel.previous, {})

    def test_intel_descriptor_discovery_lifetime(self):
        """Reuse descriptor discovery, discover new PIDs immediately and evict exited PIDs."""
        self.intel_card()
        provider = monitor.IntelGpuProvider(self.proc, self.sys)
        self.assertEqual(provider.sample(10)[0]['status'], 'unavailable')
        self.intel_client(counter=0)
        self.assertEqual(provider.sample(12)[0]['status'], 'unavailable')
        self.intel_client(client=8, counter=0, pid=13)
        self.assertEqual(provider.sample(13)[0]['clientCount'], 1)
        self.assertEqual(provider.sample(15)[0]['clientCount'], 2)
        shutil.rmtree(self.proc / '13')
        provider.sample(17)
        self.assertNotIn(('13', 100), provider.descriptors)
        self.assertEqual(len(provider.previous), 1)

    def test_intel_fd_exit_during_discovery(self):
        """A vanished descriptor cannot hide a later valid GPU descriptor."""
        self.intel_card()
        missing = self.proc / '12/fd/0'
        missing.parent.mkdir(parents=True, exist_ok=True)
        missing.symlink_to('/dev/null')
        self.intel_client()
        provider = monitor.IntelGpuProvider(self.proc, self.sys)
        original = Path.readlink
        def readlink(path):
            if path == missing:
                raise FileNotFoundError()
            return original(path)
        with patch.object(Path, 'readlink', readlink):
            self.assertEqual(provider.sample(10)[0]['clientCount'], 1)

    def test_gpu_provider_failure_isolation(self):
        """An inaccessible Intel provider cannot discard a healthy AMD GPU."""
        self.write('sys/class/drm/card0/device/vendor', '0x1002')
        self.write('sys/class/drm/card0/device/gpu_busy_percent', '52')
        collector = monitor.Monitor(self.proc, self.sys, self.mount, '')
        with patch.object(collector.intel, 'sample', side_effect=PermissionError):
            rows = collector.sample(10)['gpus']
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['usage'], 52)

    def test_disk_counter_reset(self):
        """Device counter resets cannot produce negative I/O or a division glitch."""
        self.collector.sample(10)
        self.write('proc/diskstats', '8 0 sda 1 0 1 0 1 0 2 0 0 0 0')
        sample = self.collector.sample(12)
        self.assertEqual(sample['disks']['readBps'], 0)
        self.assertEqual(sample['disks']['writeBps'], 0)

    def test_disk_exit_new_baseline_and_nonpositive_elapsed(self):
        """Removed devices release counters; new devices and zero deltas warm up."""
        self.collector.disk_io(10)
        self.write('proc/diskstats', '')
        self.assertEqual(self.collector.disk_io(11)['devices'], [])
        self.assertEqual(self.collector.previous['disk'][1], {})
        self.write('proc/diskstats', '8 0 sda 1 0 999999 0 1 0 999999 0 0 0 0')
        for now in (12, 12, 11):
            row = self.collector.disk_io(now)
            self.assertIsNone(row['readBps'])
            self.assertIsNone(row['writeBps'])

    def test_process_payload_only_on_scan(self):
        """Unchanged process rows never enter ordinary telemetry serialization."""
        with patch.object(self.collector, 'processes', wraps=self.collector.processes) as scan:
            first = self.collector.sample(10)
            for now in (10.1, 10.5, 10.9):
                frame = self.collector.sample(now)
                self.assertNotIn('processes', frame)
                self.assertNotIn('"processes"', json.dumps(frame))
                self.assertEqual(frame['processMonotonicMs'], first['processMonotonicMs'])
            second = self.collector.sample(11)
            self.assertEqual(scan.call_count, 2)
        self.assertIn('processes', second)
        self.assertEqual(second['processMonotonicMs'], 11000)
        with patch.object(self.collector, 'processes', side_effect=PermissionError):
            failed = self.collector.sample(12)
        self.assertNotIn('processes', failed)
        self.assertEqual(failed['processMonotonicMs'], 11000)
        self.assertEqual(failed['errors']['processes'], 'PermissionError')

    def test_pidfd_capability(self):
        """Only the controller's complete safe signaling path advertises process control."""
        for missing in (None, 'open', 'send'):
            with self.subTest(missing=missing), patch.object(monitor.os, 'pidfd_open', create=True), \
                    patch.object(monitor.signal, 'pidfd_send_signal', create=True):
                if missing == 'open':
                    del monitor.os.pidfd_open
                elif missing == 'send':
                    del monitor.signal.pidfd_send_signal
                self.assertEqual(self.collector.sample(10)['capabilities']['processControl'], missing is None)

    def test_intel_reused_pid_discovers_new_descriptors_immediately(self):
        """A reused PID cannot reuse the old lifetime's descriptor cache."""
        self.intel_card()
        self.process(1234, 100, 0)
        self.intel_client(pid=1234, fd=10)
        provider = monitor.IntelGpuProvider(self.proc, self.sys)
        provider.sample(10)
        self.assertIn(('1234', 100), provider.descriptors)
        self.process(1234, 200, 0)
        (self.proc / '1234/fd/10').unlink()
        self.intel_client(pid=1234, fd=14, client=8)
        original = Path.read_text
        reads = []
        def read(path, *args, **kwargs):
            reads.append(path)
            return original(path, *args, **kwargs)
        with patch.object(Path, 'read_text', read):
            row = provider.sample(12)[0]
        self.assertNotIn(('1234', 100), provider.descriptors)
        self.assertEqual([path.name for path in provider.descriptors[('1234', 200)]], ['14'])
        self.assertNotIn(self.proc / '1234/fdinfo/10', reads)
        self.assertIn(self.proc / '1234/fdinfo/14', reads)
        self.assertEqual(row['clientCount'], 1)

    def test_nvidia_timeout_and_failure(self):
        """Driver timeouts and failed commands cannot crash or leave a helper alive."""
        for failure in (subprocess.TimeoutExpired('nvidia-smi', 2), None):
            with patch.object(monitor.subprocess, 'Popen') as spawn:
                child = spawn.return_value
                child.communicate.side_effect = failure
                child.communicate.return_value = ('', None)
                child.returncode = 1
                child.poll.return_value = None
                self.assertEqual(monitor.NvidiaSmiProvider('nvidia-smi').sample(), [])
                child.communicate.assert_called_once_with(timeout=2)
                child.kill.assert_called_once()
                child.wait.assert_called_once()

    def test_interval_bounds(self):
        """CLI and service share the documented 100–2000 ms contract."""
        for interval in (99, 2001):
            result = subprocess.run([sys.executable, str(SOURCE), '--once', '--interval-ms', str(interval)],
                capture_output=True, text=True, timeout=3)
            self.assertEqual(result.returncode, 2)
            self.assertIn('100–2000', result.stderr)

    def test_malformed_and_missing_files(self):
        """Broken providers degrade independently and recover on subsequent samples."""
        self.write('proc/stat', 'cpu broken data')
        (self.proc / 'meminfo').unlink()
        self.write('proc/diskstats', 'malformed')
        self.write('sys/class/drm/card0/device/gpu_busy_percent', 'NaN')
        self.assertIsNone(monitor.number(self.sys / 'class/drm/card0/device/gpu_busy_percent'))
        sample = self.collector.sample(10)
        self.assertFalse(sample['cpu']['available'])
        self.assertFalse(sample['memory']['available'])
        self.assertEqual(sample['errors']['cpu'], 'ValueError')
        self.assertEqual(len(sample['processes']), 1)
        self.process(12, 100, 10 + self.collector.hz * 2)
        process = self.collector.sample(12)['processes'][0]
        self.assertEqual(process['cpuPercent'], 100)
        self.assertIsNone(process['cpuTotalPercent'])

    def test_termination_reaps_driver_query(self):
        """Closing during a GPU query must not leave a driver helper behind."""
        pid_file = self.root / 'driver.pid'
        executable = self.write('slow-nvidia', '#!/usr/bin/env python3\nimport os,time\n'
            + f'open({str(pid_file)!r}, "w").write(str(os.getpid()))\ntime.sleep(60)\n')
        executable.chmod(0o755)
        args = [sys.executable, str(SOURCE), '--stream', '--proc-root', str(self.proc),
                '--sys-root', str(self.sys), '--nvidia-smi', str(executable)]
        with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as child:
            deadline = time.monotonic() + 3
            while not pid_file.exists() and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(pid_file.exists())
            driver_pid = int(pid_file.read_text())
            child.terminate()
            child.communicate(timeout=3)
            self.assertEqual(child.returncode, 0)
            self.assertFalse(Path(f'/proc/{driver_pid}').exists())

    def test_stream_terminates_cleanly(self):
        """SIGTERM interrupts the stream without a traceback or orphan child."""
        args = [sys.executable, str(SOURCE), '--stream', '--proc-root', str(self.proc),
                '--sys-root', str(self.sys), '--mount-root', str(self.mount), '--nvidia-smi', '']
        with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as child:
            self.assertEqual(json.loads(child.stdout.readline())['seq'], 1)
            child.terminate()
            _, error = child.communicate(timeout=3)
            self.assertEqual(child.returncode, 0, error)


if __name__ == '__main__':
    unittest.main()
