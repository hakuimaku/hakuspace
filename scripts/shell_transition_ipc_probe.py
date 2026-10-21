#!/usr/bin/env python3
"""Exercise the real shell entrypoint inside the test compositor and D-Bus session."""

import json
import os
import subprocess
import time


# Bound every query so a broken IPC handler cannot strand the test session.
def ipc(target, method, *args):
    return subprocess.check_output(
        ["qs", "-c", "hakuspace", "ipc", "call", target, method, *args],
        text=True, stderr=subprocess.DEVNULL, timeout=2).strip()


# Reload briefly removes the IPC target; wait for the requested new generation.
def wait_phase(wanted):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        try:
            status = json.loads(ipc("shellTransition", "status"))
            if status["phase"] == wanted:
                return status
        except (ValueError, subprocess.SubprocessError):
            pass
        time.sleep(0.04)
    raise AssertionError("Transition did not reach " + wanted)


# Launch one bootstrap runtime using the actual shell and all surface hosts.
runtime = subprocess.Popen(["qs", "-c", "hakuspace"], env=dict(
    os.environ, HAKUSPACE_SHELL_TRANSITION_BOOTSTRAP="classic-to-hikai"))
try:
    assert not wait_phase("idle")["chromeEnabled"]
    assert ipc("shellTransition", "begin", "classic-to-hikai") == "ok"
    wait_phase("covered")
    assert ipc("shellTransition", "showChrome") == "ok"
    assert ipc("shellTransition", "release") == "ok"
    assert wait_phase("finished")["chromeEnabled"]

    # Bootstrap completion survives reload without persisting animation progress.
    ipc("shell", "reload")
    status = wait_phase("idle")
    assert status["chromeEnabled"] and not status["active"], status

    # Output removal and reattachment must remain safe while idle and covered.
    subprocess.run(["wlr-randr", "--output", "HEADLESS-2", "--off"], check=True)
    assert wait_phase("idle")["chromeEnabled"]
    subprocess.run(["wlr-randr", "--output", "HEADLESS-2", "--on"], check=True)
    for iteration in range(10):
        assert ipc("shellTransition", "begin", "hikai-to-classic") == "ok"
        wait_phase("covered")
        assert ipc("shellTransition", "hideChrome") == "ok"
        if iteration == 0:
            subprocess.run(["wlr-randr", "--output", "HEADLESS-2", "--off"], check=True)
            wait_phase("covered")
            subprocess.run(["wlr-randr", "--output", "HEADLESS-2", "--on"], check=True)
        assert ipc("shellTransition", "showChrome") == "ok"
        assert ipc("shellTransition", "release") == "ok"
        wait_phase("finished")

    # The production quit connection must keep the runtime alive through reveal.
    assert ipc("shellTransition", "begin", "hikai-to-classic") == "ok"
    wait_phase("covered")
    assert ipc("shellTransition", "hideChrome") == "ok"
    assert ipc("shellTransition", "releaseAndQuit") == "ok"
    assert runtime.poll() is None
    assert runtime.wait(timeout=10) == 0
    print("Shell transition IPC, reload, hotplug and repeated lifecycle checks passed", flush=True)
finally:
    if runtime.poll() is None:
        runtime.terminate()
        runtime.wait(timeout=5)
