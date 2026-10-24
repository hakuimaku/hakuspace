# Hikai

This document describes Hikai's architecture and design contracts.
It does not try to mirror every current feature, setting, token or default.
The implementation is the source of truth for those details.

[Tiếng Việt](vietnamese/hikai.md)

## What Hikai Is

Hikai is HakuSpace's Quickshell-based shell mode. Classic is another shell mode.
Hikai is a shell with shared state, services, surfaces and integrations, rather than a collection of independent widgets.

## How To Read This Documentation

Read the mental model and ownership rules first. Use the other sections when working on the relevant boundary.
These are rules for organizing changes, not a claim that every existing implementation already follows them perfectly.

Start tracing runtime behavior at the [shell source](../src/home/.config/quickshell/hakuspace/).
Follow the owner of the behavior into its callers and tests before changing it.
Look up current names, schemas, defaults and supported operations in source instead of inferring them from this guide.

## Mental Model

Think of a normal interaction as a loop:

```text
external event
    -> service/backend
    -> shared state
    -> presentation
    -> user action
    -> shared action/backend
    -> confirmed state update
```

Runtime services observe external systems. Shared state gives those observations a common meaning.
Presentation renders that state and turns input into requests.
The window manager abstraction translates compositor behavior, system integration performs domain operations, and persistent configuration keeps user choices across sessions.

A surface can disappear while its service keeps working. Showing the same data on another output should reuse its owner, not create another independent data source.

## Runtime Architecture

Quickshell composes the shell runtime, shared services and output-associated surfaces.
The session lifecycle manages startup, shutdown and recovery; a UI component should not start another shell runtime.
Reload is a lifecycle transition, so initialization and teardown must tolerate it without duplicating processes, subscriptions or protocol owners.

Use [services](../src/home/.config/quickshell/hakuspace/services/) for shared models and coordination, and [components](../src/home/.config/quickshell/hakuspace/components/) for presentation and reusable UI behavior.
System operations belong behind the appropriate service or [headless backend](../src/core/backend/).
The [core script architecture](../src/core/README.md) explains public command routing and deployment.

Keep slow work and external IO outside rendering bindings. Prefer external events over repeated polling when the system provides them.
Share expensive work and release subscriptions or processes when their last consumer no longer needs them.

## State And Ownership

Keep one owner for each piece of state. The owner defines its meaning, accepts changes and decides when it is valid.
Other components consume that state or request an action. Two surfaces showing the same value should not keep separate authoritative copies.

Separate protocol and backend state from presentation state. A service owns what an external system reports and whether a request succeeded.
A surface owns local concerns such as hover, search text or a navigation position when those concerns do not need coordination elsewhere.
Hiding a surface must not accidentally stop a shared service or erase its data.

Shared interaction state belongs to a shared coordinator when several surfaces must agree.
The coordinator decides which transient surface owns an interaction, its activation source and its output.
Presentation hosts own placement and window behavior. Shared content owns common actions and navigation, so a different presentation does not require another implementation of the feature.

Keep requested state separate from effective state. A stored user choice may be temporarily suppressed by the active layout or unavailable capability.
Derive that effective result in one place. Do not erase the user's preference just because it cannot take effect now.
Consumers should not each reconstruct the same availability or layout rule.

Persistent state and temporary UI state have different lifetimes. Persist intentional choices and user data that must survive a session.
Keep pointer ownership, captured anchors and animation progress tied to the interaction that created them.
Do not persist a transient detail merely to make it accessible to another component.

For editable data, distinguish the saved snapshot, current draft, live preview and pending operation.
These are different roles with an explicit owner, not competing copies of the same truth.
Derive dirty state from the draft and confirmed snapshot. Preview is not a successful save, and resetting a draft is not permission to overwrite storage.

Async completion must still belong to the request, draft or object that started it.
An old response must not overwrite newer edits, retarget a replacement surface or access destroyed content.
Keep failed drafts available for correction. If several saves complete separately, report partial success honestly and preserve the unsaved work.

Ownership includes cleanup. Release focus, input regions, visibility leases and subscriptions when their owner closes, transfers or disappears.
Logical close can happen before a closing animation ends; keep only the visual state needed to finish it, without leaving hidden controls interactive.
Reopening must take precedence over a stale close callback.

## Shell Surfaces

Choose a surface by its interaction contract:

| Kind | Main responsibility |
| --- | --- |
| Persistent shell chrome | Remain part of the desktop layout and own any work-area reservation it needs. |
| Temporary popup | Show short-lived content near a source, with a clear dismissal rule. |
| Panel | Host a sustained task with defined placement, focus and close behavior. |
| Overlay | Present content above other windows; decide explicitly whether it is modal. |
| Menu | Present actions and selection tied to the invoking context. |
| OSD | Report an action or state change without taking unrelated input or focus. |

For each surface, define its owner, output, anchor, input region, focus policy and lifecycle.
A visual layer is not automatically an input owner. Transparent areas should pass input through unless the interaction deliberately captures them.
An overlay does not become modal just because its window covers an output.

Keep window placement, drawn shape, interactive bounds and reserved desktop space distinct.
When separate windows render and handle input for one surface, derive both from the same geometry and transition state.
Reserve space once for each intended layout contribution; do not infer it from an animation's current shape.

## Window Manager Integration

UI components should ask for a shared model or action instead of interpreting compositor protocols themselves.
Keep compositor detection, event translation and native commands behind the appropriate window manager abstraction or backend.

Normalize shared concepts where their meanings agree. Expose capability differences and unavailable data explicitly instead of inventing values or pretending every compositor behaves alike.
Keep global state, output-local state, active state and focused state distinct where the compositor does.
Output filtering and action targeting belong in that contract, not in separate guesses made by each surface.

## Configuration And Persistence

Make something configurable when it represents a useful user choice. Keep architectural invariants in code.
Persist preferences and user-authored data; leave availability, hover, focus and in-flight work at runtime.
Generated theme data, saved settings and disposable caches have different owners and should not silently overwrite one another.

UI reads and edits settings through the shared store. The store owns drafts, previews and operation status; the backend owns storage validation and writes.
UI validation helps the user, but backend validation remains required for every caller.
Validate types, allowed values, paths and file revisions where they cross a trust boundary.
Write safely and preserve unrelated user content and permissions. A malformed read should expose an error without replacing valid data with an empty result.

Migrations belong to the persistence boundary, not to each UI consumer.
Preserve explicit choices, make repeated migration safe, and make interrupted changes recoverable.
Run a required migration before dependent runtime consumers start; a normal read should not quietly rewrite user files.
Find current option names, schemas and defaults in the [settings backends](../src/core/backend/user/) and their shared stores.

### Settings and personalisation

Settings uses one category rail. Search opens the matching category and highlights its setting; it leaves the surrounding page available. All preferences are visible in their categories, including Classic-only and inactive WM preferences; there is no Advanced disclosure. Search includes storage keys, while rows show readable labels without variable names or version metadata. Stores retain drafts and persistence formats.

General includes font family and font size. The searchable font list contains installed monospace families, using the same source as Change Theme, and refreshes every time it opens. Apply saves typography through the existing theme controller and updates the shell; Reload and Discard restore saved values. Screenshot folder help appears only for Niri, whose built-in screenshot keys use its own configuration.

The native Change Theme layer offers font family, font size and accent color, plus animation options when running Niri. Rofi and Waybar pickers remain in the Classic frontend. Theme pages share the shell's ink surface, spacing, typography and moving selection pill; native font changes call the theme controller directly.

Appearance and Desktop share shell preferences. Wallpaper folders, rotation and Classic transitions use general preferences; video quality, playback and preparation use wallpaper preferences. Apply saves the corresponding store, and Apply & Close saves all modified stores. Configuration lists every WM configuration file, with the active WM first. Recorder options live in Recording, Classic widget fonts and custom Waybar themes in Appearance, and exit options in Session. There are no separate Advanced or Shortcuts tabs.

The wallpaper picker uses saved video quality: select an item and Apply. Preparation follows the saved policy. Video cache maintenance and browser preferences are always available in Wallpaper settings. Avatar selection opens a square pan-and-zoom crop before saving a 512×512 PNG; Cancel and failed capture leave the previous avatar selected.

Native folder and image choosers temporarily release the requesting layer's keyboard ownership and lower it beneath application windows. Closing the chooser restores its owner only if that surface is still current. A pinned Temp Note remains visible independently, but shares one keyboard owner with Settings and Navigation; clicking a visible note explicitly transfers input.

## Styling And Motion

Use the shared visual language, theme-driven values and reusable primitives.
Check for an existing control or motion primitive before adding local styling.
Reuse common behavior while keeping the shape appropriate to the surface's purpose.
Keep focus, selection, hover and disabled states readable across themes and input methods.

Geometry needs one owner for attachment edges, safe bounds and coordinate conversion on each output.
Consumers should ask for those meanings instead of copying offsets from another component.
Keep shape calculation, rendering, content layout and motion separate where they have different responsibilities.

Motion should communicate state changes and preserve continuity when interrupted or reversed.
Ordinary control feedback should stay within stable layout bounds. Explicit surface transitions may change geometry, but input and focus must follow the actual interaction state.
Changing an attachment direction must keep content upright and hit testing aligned.
Use current source for visual tokens and motion profiles, not copied values in documentation.

## Input, Focus And Multi-Monitor Behavior

Give keyboard and pointer interaction clear owners. Restored window focus is not evidence of a new keyboard action.
Only capture keys needed by the interaction, and preserve text editing and normal control activation.
Keep keyboard access and visible focus available alongside pointer behavior.
Cancel the innermost active confirmation before dismissing its parent; do not lose unsaved work on close.

Define when a surface becomes ready for input and when closing releases it.
Pointer handoff between a trigger and content should use shared safe-zone behavior derived from real bounds, including the travel corridor.
Do not add unrelated timers or full-output input blockers to hide an ownership problem.

Treat output identity and coordinate space as part of every placement request.
Distinguish screen-local anchors, window-local points and physical pixels; convert them through shared geometry.
Use a real source anchor when one exists, and define the output policy for calls that have none.

A shared preference does not imply shared placement. Transfer an interaction between outputs cleanly, releasing the old owner's focus, anchors and leases.
Handle output removal, scale changes and layout changes without ghost surfaces, stale reservations or duplicated subscriptions.

## IPC And External Integration

IPC and public commands are entry points into shared actions, not separate implementations of them.
Keep domain operations headless so shell surfaces and external callers can use the same validated behavior.
Use explicit operations and stable identifiers rather than interpreting visible labels as commands.

Validate requests at the boundary, including output and source availability where relevant.
Keep a requested action separate from its confirmed result, propagate failures, and define cancellation or cleanup for requests awaiting a response.
Preserve existing callers when changing an interface, or update every affected caller and its verification together.
Read the runtime entry point and backend source for current IPC targets and arguments.

## Adding Or Changing A Feature

1. Define the owner and lifetime of the behavior.
2. Define authoritative state, derived state and local UI state.
3. Place external IO and mutation behind the service or backend boundary.
4. Choose the presentation type and reuse shared content or actions.
5. Define focus, input regions, activation source, anchors and output semantics.
6. Connect persistence only for data that needs to survive; include validation and migration when required.
7. Reuse visual, geometry and motion primitives.
8. Verify the contract, failure paths and affected callers, including other outputs and Classic where shared code changes.

Trace the existing path before adding a parallel one.
A presentation change should preserve data safety and backend semantics unless the task explicitly changes them.
Add documentation only when the feature introduces a lasting architectural concept or changes an existing contract.

## Testing And Debugging

Test at the boundary being changed. Use pure tests for geometry and model rules, backend tests for validation and persistence, and runtime tests for real QML lifecycles and input.
Syntax checks do not prove behavior. Cold startup does not prove live reload, and direct state assignment does not prove keyboard or pointer routing.

Find the current runners and fixtures in [scripts](../scripts/) and [tests](../tests/).
The [repository check script](../scripts/precommit_check.sh) defines the combined checks; inspect runner requirements and side effects before running compositor tests.
Use disposable data, isolated sessions and harmless action fixtures so verification does not edit real preferences or act on user applications.

Exercise cancellation, rapid reversal, stale responses, failed writes, disappearing sources and ownership transfer.
For placement and input changes, include constrained layouts, multiple outputs, scaling, fullscreen behavior and actual client work areas where relevant.
Headless or nested results describe those environments; they do not establish physical hardware acceptance.

Debug along the event loop: confirm the external event, service update, shared state, presentation and action result.
Inspect runtime and supervisor logs for load, binding, type and lifecycle failures before tuning visuals.
Compare geometry and input bounds when the picture looks right but interaction fails.
Keep temporary probes and screenshots outside production source, and record commands, evidence and untested cases in the issue or PR.

## Hikai And Classic

Hikai and Classic provide different presentations over shared HakuSpace operations.
Public facades route requests to the selected mode; backends should not depend on either presentation.
Keep Hikai UI state and Classic UI preferences separate unless a shared data contract is intentional.

Changing modes should preserve user choices, release the old runtime's resources and avoid competing owners of a desktop service.
Keep recovery available when Hikai cannot start. Verify shared command behavior in both modes when changing routing or backend semantics.

## Documentation Rules

Keep [English](hikai.md) and [Vietnamese](vietnamese/hikai.md) aligned in section order and meaning.
Use short sentences, short paragraphs and plain language. Use ASCII hyphens instead of Unicode en or em dashes.

Do not add current feature inventories or matrices, setting or token inventories, exact defaults, dimensions, animation values or timeouts.
Do not add temporary implementation status, roadmaps, milestone reports, dated test results, version-specific runtime reports or temporary compatibility notes.
Those details belong in source, issues, PRs or commits. Git history preserves development history; do not create a documentation archive for it.

Add a new section when a genuinely new architectural concept appears.
Edit an existing section when its contract or mental model changes, and keep links working when source moves.
Adding, renaming or redesigning a feature should not require rewriting an inventory here.
