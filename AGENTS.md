
# Scoped Validation Policy

Codex must validate changes according to the scope of the current task.

## Core rule

Do NOT run the repository-wide test suite by default.

In particular, do NOT run:

```bash
scripts/precommit_check.sh
```

after every implementation batch or small feature.

`precommit_check.sh` is a repository-wide validation suite and must be treated as a final/integration check, not as the default development test command.

## 1. Test only the current change scope

After making a change:

1. Identify the files actually changed.
2. Identify the component/service directly affected.
3. Run only:
   - syntax/static checks for changed files;
   - tests belonging to that component;
   - tests for direct consumers if a shared primitive was changed.

Do not run tests for unrelated subsystems merely because they exist in the repository.

Example:

```text
Changed:
NotificationPopup.qml
NotificationService.qml

Allowed validation:
- QML syntax for those changed QML files
- notification-specific tests/probes
- notification runtime smoke test

Do NOT automatically run:
- Dock tests
- Settings tests
- HakuMenu tests
- icon accent tests
- shell transition tests
- Labwc tests
- unrelated WM tests
```

## 2. Validation levels

### Level A — changed-file validation

Always perform lightweight checks relevant to changed files.

Examples:

QML:

```bash
python3 scripts/qml_syntax_check.py <changed-qml-files>
```

Shell:

```bash
bash -n <changed-shell-files>
```

Python:

```bash
python3 -m py_compile <changed-python-files>
```

JavaScript:

Run the specific JS test only when the changed code is covered by that test.

Also run:

```bash
git diff --check
```

These checks are cheap and may be performed routinely.

### Level B — targeted component tests

Run the smallest test set that exercises the behavior being changed.

Examples:

```text
Dock change
→ dock tests only

Settings navigation change
→ settings navigation tests only

Notification change
→ notification tests/runtime probes only

Workspace backend change
→ tests for that WM backend only

Flare geometry change
→ Flare geometry test + direct Flare consumers only
```

Do not expand to unrelated components.

### Level C — affected-dependency tests

Use this only when a changed file is shared by multiple components.

Example:

```text
Changed shared Flare primitive
→ test Tray
→ test Notification Center
```

Do not interpret "shared" as permission to test the entire repository.

Only test known direct consumers of the changed primitive.

## 3. Full-suite policy

Run:

```bash
scripts/precommit_check.sh
```

ONLY when at least one of these conditions is true:

1. The user explicitly requests a full test/precommit run.
2. The task is at final milestone / release / merge readiness.
3. A repository-wide/shared infrastructure change genuinely affects many subsystems.
4. `scripts/precommit_check.sh` itself or global test infrastructure was modified.
5. Targeted testing reveals evidence of a cross-component regression that requires broader validation.

Otherwise, do not run the full suite.

Finishing a normal feature implementation is NOT by itself sufficient reason to run the full suite.

## 4. Do not test unrelated WMs

For compositor/backend-specific changes:

```text
Hyprland change
→ do not test Niri or Mango automatically

Niri change
→ do not test Hyprland or Mango automatically

Mango change
→ do not test Hyprland or Niri automatically
```

Test multiple WMs only when:

- shared WM abstraction/code changed;
- the task explicitly requires cross-WM compatibility;
- final integration validation is requested.

## 5. Stop scope expansion

Do not modify unrelated code merely because an unrelated test fails.

If an accidentally executed unrelated test fails:

1. report the failure;
2. state that it is outside the current task scope;
3. do not investigate or fix it unless there is evidence the current change caused it.

Do not turn a focused feature task into repository cleanup.

## 6. Before running a test command

Codex must be able to answer:

```text
What changed?
What behavior does this command validate?
Why can this change affect that behavior?
```

If the third answer is unclear, do not run that test.

## 7. Final report

For each task report:

```text
Changed files:
- ...

Targeted validation:
- command → PASS/FAIL
- command → PASS/FAIL

Not run because outside scope:
- repository-wide precommit
- unrelated component suites
- unrelated compositor tests

Remaining manual checks:
- ...
```

Do not claim the entire repository is verified when only targeted tests were run.

Use the wording:

```text
Targeted validation passed for the current change scope.
Full repository suite was intentionally not run.
```

## Principle

Prefer:

```text
small change
→ small validation surface
```

and expand validation only when the dependency graph of the actual change requires it.

Do not use:

```text
small change
→ test everything
```


## Execution scope

Implement only the feature described in this task.

Validation must be scoped to the files/components changed by this task.

- Run changed-file syntax/static checks.
- Run the smallest relevant component tests.
- Test direct consumers only if shared code was changed.
- Do NOT run `scripts/precommit_check.sh` unless explicitly requested.
- Do NOT run unrelated Dock, Settings, Shell transition, HakuMenu, visual, icon, compositor, or backend tests.
- Do NOT fix unrelated failures.
- Do NOT refactor unrelated code discovered during implementation.

Before running any test, verify that the current change can reasonably affect what that test covers.

At completion, report:
1. changed files;
2. targeted tests executed;
3. pass/fail evidence;
4. checks intentionally skipped as out of scope;
5. remaining manual checks.