#!/usr/bin/env python3
"""Measure Quickshell parsing/history cost in an isolated offscreen service session."""
import argparse
import json
from pathlib import Path
import sys

from test_service import ROOT, ServiceTest

sys.path.insert(0, str(ROOT / 'tools/profiling'))
from hikai_memory_soak import measure


def profile(args):
    """Keep the same Quickshell PID and subscribers across all refresh intervals."""
    args.output.mkdir(parents=True, exist_ok=True)
    case = ServiceTest()
    result = {'renderer': 'offscreen-service-only', 'rows': []}
    try:
        case.setUp()
        case.open()
        for interval in (100, 250, 500, 1000, 2000):
            previous = case.status()['monotonicMs']
            case.ipc('interval', interval)
            case.wait(lambda: case.status()['monotonicMs'] > previous and case.status()['ready'])
            effective = case.status()['intervalMs']
            options = argparse.Namespace(software=False, outputs=0, warmup=2, seconds=args.seconds,
                cycles=0, notifications=0, backend='hikai', lock_profile=None, interval=1,
                output=args.output / f'{effective}.json')
            measure(case.child.pid, options)
            report = json.loads(options.output.read_text())
            readings = [row for row in report['samples'] if row['phase'] == 'idle']
            first, last = readings[0], readings[-1]
            assert case.status()['ready'] and not case.status()['error'], 'service must remain live'
            result['rows'].append(dict(intervalMs=effective, requestedIntervalMs=interval,
                cpuPercent=100 * (last['cpuSeconds'] - first['cpuSeconds']) / (last['elapsedSec'] - first['elapsedSec']),
                rssKiB=sum(row['rssKiB'] for row in readings) / len(readings),
                pssKiB=sum(row['pssKiB'] for row in readings) / len(readings),
                fdCount=last['fdCount'], childCount=last['childCount']))
            (args.output / 'report.json').write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps(result['rows'][-1]), flush=True)
        pid = case.status()['collectorPid']
        case.ipc('close')
        case.closed(pid)
    finally:
        case.doCleanups()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=float, default=30)
    parser.add_argument('--output', type=Path, required=True)
    profile(parser.parse_args())
