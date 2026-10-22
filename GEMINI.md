---
trigger: always_on
description: "Keep Antigravity implementation, investigation, and validation strictly scoped to the current HakuSpace task."
---

# HakuSpace — Scoped Implementation & Validation Policy

## Primary principle

Stay strictly within the scope of the current task.

The existence of additional tests, scripts, components, TODOs, warnings, or potential refactors in the repository is NOT permission to investigate, modify, or validate them.

Use this default model:

```text
task scope
→ affected files
→ affected component
→ direct dependencies
→ targeted validation
→ stop
```

Do NOT use:

```text
task
→ inspect everything
→ refactor nearby code
→ run every available test
→ fix unrelated failures
```

---

# 1. Establish scope before editing

Before making changes, determine:

1. What feature/bug/task is explicitly requested?
2. Which files are expected to implement it?
3. Which existing components are direct dependencies?
4. Which behaviors can realistically regress because of this change?
5. What is the smallest validation set capable of verifying those behaviors?

Treat that set as the task boundary.

Do not silently expand it.

If unrelated issues are discovered, note them in the final report only.

Do not fix them unless they block the requested task or the user explicitly asks for them.

---

# 2. Minimal inspection

Inspect enough code to understand the requested feature correctly.

Reading related code is allowed.

However, do not recursively audit unrelated subsystems merely because they are nearby or referenced somewhere in the repository.

Prefer:

```text
target file
→ direct dependency
→ direct consumer
```

Avoid:

```text
target file
→ entire subsystem
→ entire repository
```

Repository-wide exploration must have a concrete reason tied to the current task.

---

# 3. Editing scope

Modify only files required by the current task.

Do not:

- clean up unrelated code;
- modernize unrelated code;
- rename unrelated APIs;
- reformat unrelated files;
- resolve unrelated warnings;
- rewrite working components for architectural consistency;
- change another compositor/backend merely because one backend changed;
- modify tests unrelated to the requested behavior.

A working implementation outside the task scope should remain untouched.

Use the principle:

```text
verify before refactor
```

and:

```text
if it is unrelated and currently works, leave it alone
```

---

# 4. Validation levels

Validation must scale with the actual dependency surface of the diff.

## Level A — Changed-file checks

Perform inexpensive checks applicable to changed files.

Examples:

### QML

```bash
python3 scripts/qml_syntax_check.py <changed-qml-files>
```

Do not automatically pass every QML file in the repository.

### Shell

```bash
bash -n <changed-shell-files>
```

### Python

```bash
python3 -m py_compile <changed-python-files>
```

### Git whitespace/error check

```bash
git diff --check
```

`git diff --check` is acceptable as a routine repository-independent sanity check.

---

# 5. Level B — Targeted component validation

After changed-file validation, execute only tests or runtime probes relevant to the component being modified.

Examples:

```text
Notification code changed
→ notification tests/probes only

Dock changed
→ Dock tests only

Settings navigation changed
→ Settings navigation tests only

Tray changed
→ Tray tests/runtime smoke only

Niri backend changed
→ Niri-specific validation only

Hyprland backend changed
→ Hyprland-specific validation only

MangoWM backend changed
→ Mango-specific validation only
```

A test must have a plausible dependency path from the current diff.

Before executing a test, ask internally:

```text
What changed?

What behavior does this test verify?

How can the current change affect that behavior?
```

If the third answer has no concrete explanation, do not run the test.

---

# 6. Level C — Shared dependency validation

If shared infrastructure is modified, test its known direct consumers.

Example:

```text
Shared Flare panel primitive changed
        ↓
Tray
Notification Center
```

Validate those direct consumers.

Do NOT interpret "shared" as "run every HakuSpace test".

Another example:

```text
shared WM abstraction changed
        ↓
Hyprland
Niri
MangoWM
```

Only in this situation is cross-WM validation justified.

---

# 7. Repository-wide validation is NOT the default

Do NOT automatically run:

```bash
scripts/precommit_check.sh
```

during normal feature implementation.

Treat `scripts/precommit_check.sh` as an integration/final-validation suite.

Run it only when one of the following conditions applies:

1. The user explicitly asks for a full/precommit validation.
2. A milestone is being finalized.
3. The task is preparing for merge/release.
4. Repository-wide infrastructure was changed.
5. The precommit/test infrastructure itself was changed.
6. Targeted validation provides concrete evidence of a cross-component regression requiring wider investigation.

Completing one feature is NOT sufficient reason to run the full suite.

Do not run full-suite tests "just to be safe".

Safety comes from selecting the correct dependency surface, not from testing unrelated systems.

---

# 8. HakuSpace compositor isolation

For compositor-specific work, keep validation isolated by default.

```text
Niri implementation
→ Niri validation

Hyprland implementation
→ Hyprland validation

MangoWM implementation
→ MangoWM validation
```

Do NOT automatically test all three.

Cross-WM testing is required only when:

- shared WM code changed;
- compositor-neutral behavior changed;
- the task explicitly requires compatibility across WMs;
- final milestone/integration testing is requested.

Do not alter a working Hyprland or MangoWM implementation merely to make its architecture resemble Niri.

Behavioral correctness has priority over architectural symmetry.

---

# 9. Runtime testing must also remain scoped

Antigravity may use terminal or browser/runtime tools when useful, but runtime validation must follow the same scope rules.

Example:

```text
Notification action implementation
→ generate a notification with an action
→ activate the action
→ verify expected callback/state
→ stop
```

Do not proceed to unrelated:

```text
Dock
Settings
HakuMenu
icon accent
wallpaper
shell transition
WM switching
```

unless the current implementation can affect them.

Do not perform unrelated exploratory UI testing after the requested behavior has been proven.

---

# 10. Do not chase unrelated failures

If an unrelated test is accidentally executed and fails:

1. Determine whether the current diff can plausibly cause the failure.
2. If there is no dependency path, classify it as outside scope.
3. Report it.
4. Do not debug it.
5. Do not modify code to make it pass.

Use:

```text
Unrelated failure observed.
No dependency path from the current change was identified.
Not investigated because it is outside the current task scope.
```

Never turn a focused feature into repository maintenance without user instruction.

---

# 11. No opportunistic refactoring

Do not perform refactors merely because:

- code could be cleaner;
- another implementation uses a different pattern;
- an abstraction could theoretically be generalized;
- a neighboring file has technical debt;
- formatting is inconsistent;
- a different architecture might look more elegant.

Refactoring is allowed when it is necessary to implement the requested behavior safely.

Otherwise record the idea as an optional follow-up.

---

# 12. Avoid speculative compatibility changes

Do not make speculative changes to code paths that cannot be tested or are not affected by the current task.

Examples:

```text
Working on Niri workspace semantics
≠ rewrite Hyprland workspace handling

Working on notification images
≠ restructure Notification Center

Working on popup positioning
≠ rewrite timeout lifecycle
```

Keep independent concerns independent.

---

# 13. Stop when acceptance criteria are satisfied

Once all requested acceptance criteria pass:

```text
STOP implementation.
```

Do not continue improving the feature unless an acceptance criterion is still unmet.

Do not add extra functionality because it appears easy.

Do not expand the feature beyond the requested behavior.

---

# 14. Validation escalation rule

Start with the smallest validation surface.

Escalate only when evidence requires it.

```text
changed-file checks
        ↓
targeted component test
        ↓
direct consumers
        ↓
broader integration test
        ↓
full precommit
```

Moving downward through this chain requires justification from the current diff or a failing targeted test.

Never start from the bottom.

---

# 15. Test command selection

Prefer specific commands such as:

```text
one syntax checker
one component test
one runtime probe
```

over broad wrappers that invoke unrelated suites.

If a script internally runs many unrelated tests, do not use that script merely because it is convenient.

Run the narrower underlying test directly when possible.

---

# 16. Planning requirements

When producing an implementation plan, explicitly include:

```text
Scope:
- components to modify

Out of scope:
- components intentionally untouched

Validation:
- exact targeted checks

Full-suite:
- not planned unless escalation criteria are met
```

Do not include generic steps such as:

```text
Run all tests
Run precommit
Ensure nothing else broke
```

unless the task actually requires repository-wide validation.

---

# 17. Completion report

At the end of every implementation task, report:

```text
Changed:
- file/component
- file/component

Targeted validation:
- command/probe → PASS/FAIL
- command/probe → PASS/FAIL

Runtime evidence:
- behavior verified

Intentionally not run:
- repository-wide precommit
- unrelated component tests
- unrelated compositor tests

Out-of-scope findings:
- only if any were encountered

Remaining manual validation:
- only if actually necessary
```

If only targeted validation was performed, state:

```text
Targeted validation passed for the current change scope.
The full repository suite was intentionally not run.
```

Never state:

```text
All tests pass.
```

unless all relevant repository-wide tests were actually executed.

---

# 18. Investigation discipline

When debugging a failure:

```text
reproduce requested failure
→ inspect its direct path
→ identify cause
→ make minimal fix
→ rerun reproducer
→ run targeted regression check
→ stop
```

Do not use:

```text
failure
→ broad audit
→ multiple speculative fixes
→ unrelated cleanup
```

---

# 19. Preserve known-good areas

Existing working behavior is part of the baseline.

For components outside the diff:

```text
working + unrelated
= preserve
```

For direct consumers of shared code:

```text
working + affected
= regression-test, not redesign
```

The goal is not architectural uniformity.

The goal is correct implementation of the requested task with the smallest justified change and validation surface.

---

# 20. Final decision rule

For every potential action — reading a file, editing a file, executing a command, running a test, launching a runtime probe, or investigating a failure — ask:

```text
Is this action necessary to implement or verify the current requested behavior?
```

If YES:

```text
proceed
```

If NO:

```text
do not do it
```

If MAYBE:

```text
prefer not to expand scope unless evidence from the current task requires it
```