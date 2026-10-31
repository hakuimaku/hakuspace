#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Limit regression checks to Task Manager and its changed QML integration files.
TASK_TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TASK_REPO_ROOT="$(cd -- "$TASK_TEST_DIR/../../.." && pwd)"
cd -- "$TASK_REPO_ROOT"
python3 -m unittest discover -s tests/hikai/task_manager -p 'test_*.py' -v
node tests/hikai/task_manager/test_logic.js
bash -n src/core/util/task_manager.sh tests/hikai/task_manager/run.sh
python3 tools/checks/qml_syntax.py \
    src/home/.config/quickshell/hakuspace/services/{TaskManagerService,UiState}.qml \
    src/home/.config/quickshell/hakuspace/components/{TaskManagerOverlay,EphemeralSurfaces,MemoryMaintenanceHost,SettingsPanel,NavigationPanel}.qml \
    src/home/.config/quickshell/hakuspace/components/taskmanager/{TaskManagerContent,TaskManagerSummary,TaskManagerProcessRow}.qml \
    src/home/.config/quickshell/hakuspace/shell.qml \
    tests/hikai/task_manager/harness/{task_manager,profile}.qml
git diff --check
