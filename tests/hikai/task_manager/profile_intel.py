#!/usr/bin/env python3
"""Compare Intel discovery and cached fdinfo reads against deterministic process fixtures."""
import argparse
import importlib.util
import json
from pathlib import Path
import time

from test_monitor import MonitorTest, SOURCE


def profile(source):
    """Use identical 100/300/500-process fixtures without requiring Intel hardware."""
    spec = importlib.util.spec_from_file_location('profiled_monitor', source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    rows = []
    for count in (100, 300, 500):
        fixture = MonitorTest()
        fixture.setUp()
        try:
            fixture.intel_card()
            for pid in range(12, 12 + count):
                fixture.intel_client(pid=pid, client=pid)
            timings = {'discovery': [], 'cached': [], 'fdinfoRead': []}
            cpu = time.process_time()
            wall = time.perf_counter()
            for _ in range(20):
                provider = module.IntelGpuProvider(fixture.proc, fixture.sys)
                for label, now in (('discovery', 10), ('cached', 12)):
                    start = time.perf_counter()
                    clients, _ = provider.clients(now)
                    timings[label].append((time.perf_counter() - start) * 1000)
                    assert len(clients) == count, 'fixture must expose one unique client per process'
                start = time.perf_counter()
                for pid in range(12, 12 + count):
                    (fixture.proc / str(pid) / 'fdinfo/8').read_text()
                timings['fdinfoRead'].append((time.perf_counter() - start) * 1000)
            rows.append(dict(processes=count, iterations=20,
                cpuSeconds=time.process_time() - cpu, wallSeconds=time.perf_counter() - wall,
                **{key + 'Ms': sum(values) / len(values) for key, values in timings.items()}))
        finally:
            fixture.doCleanups()
    return rows


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = dict(source=str(args.source), fixture=True, rows=profile(args.source))
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
