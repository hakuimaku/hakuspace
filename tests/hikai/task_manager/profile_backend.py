#!/usr/bin/env python3
"""Measure collector traffic and resources without retaining production debug output."""
import argparse
import json
from pathlib import Path
import selectors
import subprocess
import sys
import time

# Reuse the live-PID sampler used by Hikai's memory soak tooling.
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/profiling'))
from hikai_memory_soak import sample


def profile(source, interval, seconds, warmup, roots=()):
    """Drain stdout continuously while sampling the same warmed collector PID."""
    command = [sys.executable, str(source), '--stream', '--interval-ms', str(interval), *roots]
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as child:
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(child.stdout, selectors.EVENT_READ)
                deadline = time.monotonic() + warmup
                end = deadline + seconds
                baseline, readings, sizes, stamps, counts = None, [], [], set(), []
                legacy_sizes, processes = [], []
                next_sample = deadline
                while time.monotonic() < end:
                    if child.poll() is not None:
                        raise RuntimeError(child.stderr.read().decode())
                    if selector.select(timeout=0.1):
                        line = child.stdout.readline()
                        value = json.loads(line)
                        if isinstance(value.get('processes'), list):
                            processes = value['processes']
                        if deadline <= time.monotonic() < end:
                            sizes.append(len(line))
                            stamps.add(value['processMonotonicMs'])
                            # Replay the former repeated-array schema against exactly the same rows.
                            legacy_sizes.append(len((json.dumps(value | {'processes': processes}, allow_nan=False) + '\n').encode()))
                            if isinstance(value.get('processes'), list):
                                counts.append(len(value['processes']))
                    if time.monotonic() >= next_sample:
                        reading = sample(child.pid)
                        if baseline is None:
                            baseline = reading
                            started = time.monotonic()
                        readings.append(reading)
                        next_sample = time.monotonic() + 1
                final = sample(child.pid)
                elapsed = time.monotonic() - started
                frames = len(sizes)
                assert frames and readings and counts, 'profile must observe frames and fresh process scans'
                return dict(intervalMs=interval, seconds=seconds, warmupSeconds=warmup,
                    cpuPercent=100 * (final['cpuSeconds'] - baseline['cpuSeconds']) / elapsed,
                    rssKiB=sum(row['rssKiB'] for row in readings) / len(readings),
                    pssKiB=sum(row['pssKiB'] for row in readings) / len(readings),
                    bytesPerFrame=sum(sizes) / frames, bytesPerSecond=sum(sizes) / seconds,
                    legacyBytesPerFrame=sum(legacy_sizes) / frames, legacyBytesPerSecond=sum(legacy_sizes) / seconds,
                    framesPerSecond=frames / seconds, processSnapshotsPerSecond=len(stamps) / seconds,
                    processCountMin=min(counts), processCountMax=max(counts),
                    fdCount=final['fdCount'], threadCount=final['threadCount'])
        finally:
            child.terminate()
            child.communicate(timeout=5)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'src/core/backend/system/task_manager_monitor.py')
    parser.add_argument('--seconds', type=float, default=30)
    parser.add_argument('--warmup', type=float, default=2)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--fixture-processes', type=int, default=0)
    args = parser.parse_args()
    report = {'source': str(args.source), 'fixtureProcesses': args.fixture_processes, 'rows': []}
    fixture, roots = None, []
    try:
        if args.fixture_processes:
            from test_monitor import MonitorTest
            fixture = MonitorTest()
            fixture.setUp()
            for pid in range(13, 12 + args.fixture_processes):
                fixture.process(pid, 100, 10)
            roots = ['--proc-root', str(fixture.proc), '--sys-root', str(fixture.sys),
                '--mount-root', str(fixture.mount), '--nvidia-smi', '']
        for interval in (100, 250, 500, 1000, 2000):
            report['rows'].append(profile(args.source, interval, args.seconds, args.warmup, roots))
            if fixture:
                assert report['rows'][-1]['processCountMin'] == args.fixture_processes
            args.output.write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps(report['rows'][-1]), flush=True)
    finally:
        if fixture:
            fixture.doCleanups()
