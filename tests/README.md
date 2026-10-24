# HakuSpace tests

Regression tests live under their owning component. Keep feature harnesses beside their tests in `harness/`; shared Wayland and tray fixtures live in `support/fixtures/`.

Run only the affected component during development. Component entrypoints resolve the repository from their own location and can be called from any working directory:

```bash
bash tests/hikai/dock/run.sh
bash tests/hikai/settings/run.sh
bash tests/hikai/wallpaper/run.sh
bash tests/shell/transition/run.sh
```

The Dock, Settings and Wallpaper runners accept `--runtime` to include their private headless Labwc checks. The transition runner accepts `--headless` to include its compositor and IPC checks. Existing nested Niri checks in the Wallpaper Python tests require Niri and a parent Wayland display. Runtime checks need their compositor, Quickshell and media/input dependencies; inspect the component test before running it.

Other components can be checked directly with `python3 tests/<component>/test_*.py`, `node tests/<component>/test_*.js` or `bash tests/<component>/test_*.sh`, using a specific test filename. Pixel tests consume captures from their component runtime harness rather than creating a desktop session themselves.

Use disposable state and `/tmp` for artifacts. Runners disable Python bytecode writes; for direct Python invocations use `PYTHONDONTWRITEBYTECODE=1`.

Developer checks are in `tools/checks/`, manual probes in `tools/probes/`, and memory/wallpaper soak tools in `tools/profiling/`. Long profiling workloads are never part of the fast regression suite.

`bash tools/checks/repo_check.sh` is the final integration orchestrator. Run it only under the repository's scoped validation policy, such as when changing shared test infrastructure. It reports skipped runtime groups when dependencies are unavailable. It does not launch the nested Hyprland Window Navigator test or interactive manual probes.
