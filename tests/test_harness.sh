#!/usr/bin/env bash
# HakuSpace Dotfiles Modularization Test Harness
# Runs tests in an isolated temporary HOME directory.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
TEST_HOME="$(mktemp -d -t hakuspace_test_home_XXXXXX)"

cleanup() {
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

echo "=== HAKUSPACE TEST HARNESS ==="
echo "Repo Dir:  $REPO_DIR"
echo "Test HOME: $TEST_HOME"

export HOME="$TEST_HOME"
export HAKU_DIR="$REPO_DIR"

pass_count=0
fail_count=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-Assertion failed}"
    if [[ "$expected" == "$actual" ]]; then
        pass_count=$((pass_count + 1))
    else
        echo "FAIL: $msg"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        fail_count=$((fail_count + 1))
    fi
}

assert_true() {
    local cmd="$1"
    local msg="${2:-Command should succeed}"
    if eval "$cmd"; then
        pass_count=$((pass_count + 1))
    else
        echo "FAIL: $msg ('$cmd' exited non-zero)"
        fail_count=$((fail_count + 1))
    fi
}

# ------------------------------------------------------------------------------
# Test 1: Runtime context
# ------------------------------------------------------------------------------
echo "--- Testing runtime.sh ---"
(
    unset HAKUSPACE_RUN_ID BACKUP_TS BACKUP_DIR
    source "$REPO_DIR/scripts/runtime.sh"
    [[ -n "$HAKUSPACE_RUN_ID" ]] || exit 1
    [[ -n "$BACKUP_DIR" ]] || exit 1
    [[ "$BACKUP_DIR" == "$TEST_HOME/.backup/Backup_"* ]] || exit 1
)
assert_true "( unset HAKUSPACE_RUN_ID BACKUP_TS BACKUP_DIR; source '$REPO_DIR/scripts/runtime.sh'; [[ -n \"\$HAKUSPACE_RUN_ID\" && \"\$BACKUP_DIR\" == \"$TEST_HOME/.backup/Backup_\"* ]] )" "runtime.sh initializes BACKUP_DIR"

# Test inheritance of BACKUP_DIR
(
    export BACKUP_DIR="$TEST_HOME/.backup/CustomBackup"
    export HAKUSPACE_RUN_ID="CustomRunID"
    source "$REPO_DIR/scripts/runtime.sh"
    [[ "$BACKUP_DIR" == "$TEST_HOME/.backup/CustomBackup" ]] || exit 1
    [[ "$HAKUSPACE_RUN_ID" == "CustomRunID" ]] || exit 1
)
assert_true "( export BACKUP_DIR='$TEST_HOME/.backup/CustomBackup'; export HAKUSPACE_RUN_ID='CustomRunID'; source '$REPO_DIR/scripts/runtime.sh'; [[ \"\$BACKUP_DIR\" == '$TEST_HOME/.backup/CustomBackup' && \"\$HAKUSPACE_RUN_ID\" == 'CustomRunID' ]] )" "runtime.sh preserves inherited BACKUP_DIR and RUN_ID"

# ------------------------------------------------------------------------------
# Test 2: Filesystem primitives
# ------------------------------------------------------------------------------
echo "--- Testing filesystem.sh ---"
source "$REPO_DIR/scripts/variables.sh"
source "$REPO_DIR/scripts/functions.sh"
source "$REPO_DIR/scripts/filesystem.sh"

test_dir="$TEST_HOME/test_dir"
ensure_dir "$test_dir"
assert_true "[[ -d '$test_dir' ]]" "ensure_dir creates directory"

test_src="$TEST_HOME/test_src.txt"
test_dst="$TEST_HOME/test_dst.txt"
echo "hello" > "$test_src"
copy_file "$test_src" "$test_dst" 1
assert_true "[[ -f '$test_dst' && \"\$(cat '$test_dst')\" == 'hello' ]]" "copy_file copies file"

# Backup on copy
echo "world" > "$test_src"
copy_file "$test_src" "$test_dst" 0
assert_true "[[ \"\$(cat '$test_dst')\" == 'world' ]]" "copy_file overwrites dst"
assert_true "[[ -f '$BACKUP_DIR/test_dst.txt' && \"\$(cat '$BACKUP_DIR/test_dst.txt')\" == 'hello' ]]" "copy_file backed up original dst"

# ------------------------------------------------------------------------------
# Test 3: Registry
# ------------------------------------------------------------------------------
echo "--- Testing registry.sh ---"
source "$REPO_DIR/scripts/registry.sh"

assert_true "registry_is_once_config 'Thunar'" "registry_is_once_config recognizes Thunar"
assert_true "registry_is_once_config '$SOURCE_CONFIG/mpv'" "registry_is_once_config recognizes full path mpv"
assert_true "! registry_is_once_config 'kitty'" "registry_is_once_config rejects kitty"

assert_true "registry_is_skip_config 'hypr'" "registry_is_skip_config recognizes hypr"
assert_true "registry_is_skip_config '$SOURCE_CONFIG/niri'" "registry_is_skip_config recognizes niri full path"
assert_true "! registry_is_skip_config 'kitty'" "registry_is_skip_config rejects kitty"

common_configs="$(registry_get_common_configs)"
assert_true "echo '$common_configs' | grep -q 'kitty'" "registry_get_common_configs contains kitty"
assert_true "echo '$common_configs' | grep -q 'quickshell'" "registry_get_common_configs contains quickshell"
assert_true "echo '$common_configs' | grep -q 'gtk-3.0/gtk.css'" "registry_get_common_configs contains gtk-3.0/gtk.css"
assert_true "echo '$common_configs' | grep -q '.nanorc'" "registry_get_common_configs contains .nanorc"
assert_true "echo '$common_configs' | grep -q '.zshrc'" "registry_get_common_configs contains .zshrc"
assert_true "echo '$common_configs' | grep -q 'hypridle.conf'" "registry_get_common_configs contains hypridle.conf"

niri_configs="$(registry_get_wm_configs 'niri')"
assert_true "echo '$niri_configs' | grep -q '$SOURCE_CONFIG/niri|$DEST_CONFIG/niri'" "registry_get_wm_configs niri maps properly"

hypr_configs="$(registry_get_wm_configs 'hyprland')"
assert_true "echo '$hypr_configs' | grep -q '$SOURCE_CONFIG/hypr/config|$DEST_CONFIG/hypr/config'" "registry_get_wm_configs hyprland maps config"
assert_true "echo '$hypr_configs' | grep -q '$SOURCE_CONFIG/hypr/hyprland.lua|$DEST_CONFIG/hypr/hyprland.lua'" "registry_get_wm_configs hyprland maps hyprland.lua"

modules="$(registry_list_modules)"
assert_true "echo '$modules' | grep -q 'quickshell'" "registry_list_modules contains quickshell"
assert_true "echo '$modules' | grep -q 'niri'" "registry_list_modules contains niri"
assert_true "echo '$modules' | grep -q 'core'" "registry_list_modules contains core"

quickshell_resolved="$(registry_resolve_module 'quickshell')"
assert_eq "$SOURCE_CONFIG/quickshell|$DEST_CONFIG/quickshell" "$quickshell_resolved" "registry_resolve_module quickshell"

destinations="$(registry_get_managed_destinations)"
assert_true "echo '$destinations' | grep -q '$DEST_CONFIG/quickshell'" "managed destinations contains quickshell"
assert_true "echo '$destinations' | grep -q '$DEST_CONFIG/niri'" "managed destinations contains niri"
assert_true "echo '$destinations' | grep -q '$DEST_BIN/haku_theme.sh'" "managed destinations contains core script haku_theme.sh"

# ------------------------------------------------------------------------------
# Test 4: Batch B modules (select_wm, deploy_mode, link, unlink, core, once, legacy_copy)
# ------------------------------------------------------------------------------
echo "--- Testing Batch B modules ---"

# select_wm.sh
assert_eq "hyprland" "$("$REPO_DIR/scripts/select_wm.sh" --validate 1)" "select_wm validates 1 as hyprland"
assert_eq "niri" "$("$REPO_DIR/scripts/select_wm.sh" --validate niri)" "select_wm validates niri"
assert_true "! '$REPO_DIR/scripts/select_wm.sh' --validate invalid_wm_name >/dev/null 2>&1" "select_wm rejects invalid wm"

# deploy_mode.sh
detected_mode="$("$REPO_DIR/scripts/deploy_mode.sh" detect --silent)"
assert_eq "symlink" "$detected_mode" "deploy_mode detect in empty home returns symlink"

# link.sh
assert_true "'$REPO_DIR/link.sh' quickshell" "link.sh quickshell succeeds"
assert_true "[[ -d '$TEST_HOME/.config/quickshell' && ! -L '$TEST_HOME/.config/quickshell' ]]" "quickshell destination is real directory (deep symlink)"
# Check that files inside are symlinks
first_qs_file="$(find "$TEST_HOME/.config/quickshell" -type l -print -quit)"
assert_true "[[ -n '$first_qs_file' && -L '$first_qs_file' ]]" "quickshell contains deep symlinks"
# Check idempotency
assert_true "'$REPO_DIR/link.sh' quickshell" "link.sh quickshell is idempotent"

# link.sh core
assert_true "'$REPO_DIR/link.sh' core" "link.sh core succeeds"
assert_true "[[ -L '$TEST_HOME/.local/bin/haku_theme.sh' ]]" "core script haku_theme.sh is symlinked"

# unlink.sh
# Create a dummy user file in quickshell directory
echo "user custom data" > "$TEST_HOME/.config/quickshell/user_custom.txt"
assert_true "'$REPO_DIR/unlink.sh' quickshell" "unlink.sh quickshell succeeds"
assert_true "[[ -f '$TEST_HOME/.config/quickshell/user_custom.txt' ]]" "unlink preserves user non-tracked files"
assert_true "[[ ! -L '$first_qs_file' ]]" "unlink removed tracked symlink"
# Cleanup dummy user file
rm -f "$TEST_HOME/.config/quickshell/user_custom.txt"
rmdir "$TEST_HOME/.config/quickshell" 2>/dev/null || true

# unlink core
assert_true "'$REPO_DIR/unlink.sh' core" "unlink.sh core succeeds"
assert_true "[[ ! -e '$TEST_HOME/.local/bin/haku_theme.sh' ]]" "unlink core removed haku_theme.sh link"

# once_configs.sh
assert_true "'$REPO_DIR/scripts/once_configs.sh'" "once_configs.sh succeeds"
assert_true "[[ -f '$TEST_HOME/.config/mpv/mpv.conf' || -d '$TEST_HOME/.config/mpv' ]]" "once_configs deployed mpv"
assert_true "[[ ! -L '$TEST_HOME/.config/mpv' ]]" "once_configs mpv is not a symlink"

# legacy_copy.sh
assert_true "'$REPO_DIR/scripts/legacy_copy.sh' config '$REPO_DIR/src/home/.nanorc' '$TEST_HOME/.nanorc'" "legacy_copy config copies file"
assert_true "[[ -f '$TEST_HOME/.nanorc' && ! -L '$TEST_HOME/.nanorc' ]]" "legacy_copy deployed real file, not symlink"

# ------------------------------------------------------------------------------
# Test 5: Batch C modules (packages, directories, assets, nixos, dependencies)
# ------------------------------------------------------------------------------
echo "--- Testing Batch C modules ---"

# packages.sh
assert_true "'$REPO_DIR/packages.sh' --list | grep -q 'core'" "packages.sh --list works"
assert_true "'$REPO_DIR/packages.sh' --dry-run core" "packages.sh --dry-run core succeeds"
assert_true "'$REPO_DIR/packages.sh' --dry-run --profile install niri" "packages.sh --dry-run --profile install succeeds"

# directories.sh
assert_true "'$REPO_DIR/scripts/directories.sh'" "directories.sh succeeds"
assert_true "[[ -d '$TEST_HOME/.icons' && -d '$TEST_HOME/.themes' && -d '$TEST_HOME/Pictures/Wallpapers' && -d '$TEST_HOME/Pictures/Screenshots' ]]" "directories.sh creates all expected directories"

# assets.sh
assert_true "'$REPO_DIR/scripts/assets.sh' --dry-run" "assets.sh --dry-run succeeds"

# nixos.sh
assert_eq "not_nixos" "$("$REPO_DIR/scripts/nixos.sh" status)" "nixos.sh status reports not_nixos"
assert_true "'$REPO_DIR/scripts/nixos.sh' rebuild" "nixos.sh rebuild safely skips on non-NixOS"

# ------------------------------------------------------------------------------
# Test 6: Batch D modules (state, hakucfg, shell_setup, display_manager, desktop_defaults, reload, repo_update)
# ------------------------------------------------------------------------------
echo "--- Testing Batch D modules ---"

# state.sh
assert_true "! '$REPO_DIR/scripts/state.sh' check >/dev/null 2>&1" "state check fails when uninitialized"
assert_true "'$REPO_DIR/scripts/state.sh' init" "state init succeeds"
assert_true "'$REPO_DIR/scripts/state.sh' check" "state check succeeds after init"

# hakucfg.sh
assert_true "! '$REPO_DIR/scripts/hakucfg.sh' check >/dev/null 2>&1" "hakucfg check fails when uninitialized"
assert_true "'$REPO_DIR/scripts/hakucfg.sh' sync --yes" "hakucfg sync succeeds"
assert_true "'$REPO_DIR/scripts/hakucfg.sh' check" "hakucfg check succeeds after sync"

# shell_setup.sh
assert_true "'$REPO_DIR/scripts/shell_setup.sh' --dry-run" "shell_setup --dry-run succeeds"

# display_manager.sh
assert_true "'$REPO_DIR/scripts/display_manager.sh' --dry-run" "display_manager --dry-run succeeds"

# desktop_defaults.sh
assert_true "'$REPO_DIR/scripts/desktop_defaults.sh' --dry-run" "desktop_defaults --dry-run succeeds"

# reload.sh
assert_true "'$REPO_DIR/scripts/reload.sh' waybar" "reload waybar succeeds"

# repo_update.sh
assert_true "'$REPO_DIR/scripts/repo_update.sh' --mode skip" "repo_update skip succeeds"

# ------------------------------------------------------------------------------
# Test 7: Batch E doctor module
# ------------------------------------------------------------------------------
echo "--- Testing Batch E doctor ---"
# Ensure common links are present
"$REPO_DIR/link.sh" --all >/dev/null 2>&1
assert_true "'$REPO_DIR/doctor.sh'" "doctor.sh succeeds on healthy profile"

# ------------------------------------------------------------------------------
# Test 8: Batch H rollback managed destinations integration
# ------------------------------------------------------------------------------
echo "--- Testing Batch H rollback integration ---"
(
    source "$REPO_DIR/scripts/variables.sh"
    source "$REPO_DIR/scripts/functions.sh"
    source "$REPO_DIR/scripts/registry.sh"
    MANAGED_DESTINATIONS=()
    add_managed_destination() { MANAGED_DESTINATIONS+=("$1"); }
    is_once_config() { registry_is_once_config "$1"; }
    build_managed_destinations() {
        MANAGED_DESTINATIONS=()
        while IFS= read -r dest; do
            [[ -z "$dest" ]] && continue
            add_managed_destination "$dest"
        done < <(registry_get_managed_destinations)
    }
    build_managed_destinations
    [[ " ${MANAGED_DESTINATIONS[*]} " =~ " $DEST_CONFIG/quickshell " ]] || exit 1
    [[ " ${MANAGED_DESTINATIONS[*]} " =~ " $DEST_CONFIG/niri " ]] || exit 1
    [[ " ${MANAGED_DESTINATIONS[*]} " =~ " $DEST_BIN/haku_theme.sh " ]] || exit 1
)
assert_true "(
    source '$REPO_DIR/scripts/variables.sh'
    source '$REPO_DIR/scripts/functions.sh'
    source '$REPO_DIR/scripts/registry.sh'
    MANAGED_DESTINATIONS=()
    add_managed_destination() { MANAGED_DESTINATIONS+=(\"\$1\"); }
    build_managed_destinations() {
        MANAGED_DESTINATIONS=()
        while IFS= read -r dest; do
            [[ -z \"\$dest\" ]] && continue
            add_managed_destination \"\$dest\"
        done < <(registry_get_managed_destinations)
    }
    build_managed_destinations
    [[ \" \${MANAGED_DESTINATIONS[*]} \" =~ \" \$DEST_CONFIG/quickshell \" ]] || exit 1
    [[ \" \${MANAGED_DESTINATIONS[*]} \" =~ \" \$DEST_CONFIG/niri \" ]] || exit 1
    [[ \" \${MANAGED_DESTINATIONS[*]} \" =~ \" \$DEST_BIN/haku_theme.sh \" ]] || exit 1
)" "rollback build_managed_destinations uses registry and finds targets"

# ------------------------------------------------------------------------------
# Test 9: Batch J.1 Interactive UX & Stream Contracts (Tests A-E)
# ------------------------------------------------------------------------------
echo "--- Testing Batch J.1 Interactive UX & Stream Contracts ---"

# Test A — Window Manager stream contract
wm_ui_file="$TEST_HOME/wm_ui.txt"
wm_stdout="$(printf '2\n' | "$REPO_DIR/scripts/select_wm.sh" 2>"$wm_ui_file")"
assert_eq "niri" "$wm_stdout" "Test A: select_wm.sh stdout is strictly 'niri'"
assert_true "! echo '$wm_stdout' | grep -qi 'Hyprland'" "Test A: select_wm.sh stdout does not contain menu text"
assert_true "grep -q '\[1\] Hyprland' '$wm_ui_file'" "Test A: UI stream contains [1] Hyprland"
assert_true "grep -q '\[2\] Niri' '$wm_ui_file'" "Test A: UI stream contains [2] Niri"
assert_true "grep -q '\[3\] MangoWM' '$wm_ui_file'" "Test A: UI stream contains [3] MangoWM"
assert_true "grep -q 'Lightweight & ton of layouts compositor' '$wm_ui_file'" "Test A: UI stream contains MangoWM description"
assert_true "grep -q '\[4\] Labwc' '$wm_ui_file'" "Test A: UI stream contains [4] Labwc"
assert_true "grep -q 'Lightweight, legacy & floating window compositor' '$wm_ui_file'" "Test A: UI stream contains Labwc description"
assert_true "grep -q '\[5\] All' '$wm_ui_file'" "Test A: UI stream contains [5] All"
assert_true "grep -q 'Choose Window Manager' '$wm_ui_file'" "Test A: UI stream contains prompt 'Choose Window Manager'"

# Test B — Deployment stream contract
dm_ui_file_1="$TEST_HOME/dm_ui_1.txt"
dm_stdout_1="$(printf '1\n' | "$REPO_DIR/scripts/deploy_mode.sh" select 2>"$dm_ui_file_1")"
assert_eq "symlink" "$dm_stdout_1" "Test B: deploy_mode.sh select (1) stdout is strictly 'symlink'"
assert_true "grep -q 'Symlink' '$dm_ui_file_1'" "Test B: UI stream contains Symlink"
assert_true "grep -q 'Copy' '$dm_ui_file_1'" "Test B: UI stream contains Copy"
assert_true "grep -q 'Choose deployment mode' '$dm_ui_file_1'" "Test B: UI stream contains prompt 'Choose deployment mode'"

dm_ui_file_2="$TEST_HOME/dm_ui_2.txt"
dm_stdout_2="$(printf '2\n' | "$REPO_DIR/scripts/deploy_mode.sh" select 2>"$dm_ui_file_2")"
assert_eq "copy" "$dm_stdout_2" "Test B: deploy_mode.sh select (2) stdout is strictly 'copy'"

# Test C — Actual command substitution pattern used by installer
cmd_sub_wm="$("$REPO_DIR/scripts/select_wm.sh" <<< "2" 2>/dev/null)"
assert_eq "niri" "$cmd_sub_wm" "Test C: command substitution value=\$(select_wm.sh) equals 'niri'"

cmd_sub_all="$("$REPO_DIR/scripts/select_wm.sh" <<< "5" 2>/dev/null)"
assert_eq "niri mango labwc hyprland" "$cmd_sub_all" "Test C: command substitution value=\$(select_wm.sh) for 5 equals 'niri mango labwc hyprland'"

cmd_sub_default="$("$REPO_DIR/scripts/select_wm.sh" <<< "" 2>/dev/null)"
assert_eq "niri mango labwc hyprland" "$cmd_sub_default" "Test C: command substitution value=\$(select_wm.sh) on Enter defaults to all"

cmd_sub_dm="$("$REPO_DIR/scripts/deploy_mode.sh" select <<< "1" 2>/dev/null)"
assert_eq "symlink" "$cmd_sub_dm" "Test C: command substitution value=\$(deploy_mode.sh select) equals 'symlink'"

# Test D — Package plan output for install vs update
install_plan="$("$REPO_DIR/scripts/packages.sh" --profile install niri --plan)"
assert_true "echo '$install_plan' | grep -q 'PACKAGE INSTALLATION PLAN'" "Test D: install plan header present"
assert_true "echo '$install_plan' | grep -q '• Niri'" "Test D: install plan shows friendly WM name Niri"
assert_true "echo '$install_plan' | grep -q '• niri'" "Test D: install plan contains group niri"
assert_true "echo '$install_plan' | grep -q '• core'" "Test D: install plan contains group core"
assert_true "echo '$install_plan' | grep -q '• service'" "Test D: install plan contains group service"
assert_true "echo '$install_plan' | grep -q '• optional'" "Test D: install plan contains group optional"

update_plan="$("$REPO_DIR/scripts/packages.sh" --profile update niri --plan)"
assert_true "echo '$update_plan' | grep -q 'PACKAGE UPDATE PLAN'" "Test D: update plan header present"
assert_true "echo '$update_plan' | grep -q '• niri'" "Test D: update plan contains group niri"
assert_true "echo '$update_plan' | grep -q '• core'" "Test D: update plan contains group core"
assert_true "echo '$update_plan' | grep -q '• service'" "Test D: update plan contains group service"
assert_true "! echo '$update_plan' | grep -q '• optional'" "Test D: update plan does NOT contain optional"

# Test E — Package plan must match execution (using mocked yay)
mock_bin="$TEST_HOME/mock_bin"
mkdir -p "$mock_bin"
yay_captured="$TEST_HOME/yay_captured_pkgs.txt"
: > "$yay_captured"
cat > "$mock_bin/yay" <<EOF
#!/usr/bin/env bash
cat >> "$yay_captured"
EOF
chmod +x "$mock_bin/yay"

PATH="$mock_bin:$PATH" "$REPO_DIR/scripts/packages.sh" --profile install niri >/dev/null

# Extract packages expected by the plan's resolved groups
expected_pkgs_file="$TEST_HOME/expected_plan_pkgs.txt"
: > "$expected_pkgs_file"
plan_groups="$(echo "$install_plan" | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Package groups:/{flag=1; next} /^Sources:/{flag=0} flag && /•/ {print $2}')"
assert_eq $'niri\ncore\nservice\noptional' "$plan_groups" "Test E: plan resolved groups match expected install profile order"

for g in $plan_groups; do
    pfile="$(registry_get_package_file "$g")"
    sed 's/[[:space:]]*#.*$//' "$pfile" | grep -E '^[a-zA-Z0-9@._+-]+$' >> "$expected_pkgs_file" || true
done

assert_eq "$(cat "$expected_pkgs_file")" "$(cat "$yay_captured")" "Test E: packages sent to yay in execution match package plan 100%"

echo "=== SUMMARY ==="
echo "PASS: $pass_count"
echo "FAIL: $fail_count"

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
echo "ALL TESTS PASSED!"
