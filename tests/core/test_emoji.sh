#!/usr/bin/env bash
set -euo pipefail

# Targeted unit & integration test for emoji backend, facade, and launcher routing.

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd -- "$REPO_ROOT"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

mock_bin="$test_dir/bin"
mkdir -p "$mock_bin"

# 1. Test emoji_ctl.sh --help and invalid commands
"$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" --help >/dev/null || {
    echo "FAIL: emoji_ctl.sh --help failed" >&2
    exit 1
}

if "$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" invalid_cmd 2>/dev/null; then
    echo "FAIL: emoji_ctl.sh should exit nonzero on unknown command" >&2
    exit 1
fi

# 2. Test emoji_ctl.sh list with custom fixture
fixture_file="$test_dir/emojis.txt"
cat > "$fixture_file" <<'EOF'
😀	Smileys & Emotion	face-smiling	grinning face	cheerful | smile
🚀	Travel & Places	transport-air	rocket	launch | space
EOF

export HAKUSPACE_EMOJI_FILE="$fixture_file"
output=$("$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" list)
line_count=$(printf '%s\n' "$output" | wc -l)
if [[ "$line_count" -ne 2 ]]; then
    echo "FAIL: expected 2 emoji lines, got $line_count" >&2
    exit 1
fi

# 3. Test emoji_ctl.sh copy with argument and stdin
cache_dir="$test_dir/cache/hakuspace/emoji"
export HAKUSPACE_EMOJI_CACHE_DIR="$cache_dir"

copied_file="$test_dir/copied.txt"
cat > "$mock_bin/wl-copy" <<MOCK_WL_COPY
#!/usr/bin/env bash
cat > "$copied_file"
MOCK_WL_COPY
chmod +x "$mock_bin/wl-copy"

# Verify initial default history (empty when no emojis copied yet)
initial_hist=$("$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" history)
if [[ -n "$initial_hist" ]]; then
    echo "FAIL: expected empty default history, got '$initial_hist'" >&2
    exit 1
fi

PATH="$mock_bin:$PATH" "$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" copy "🎉"
copied_val=$(cat "$copied_file")
if [[ "$copied_val" != "🎉" ]]; then
    echo "FAIL: expected '🎉', got '$copied_val'" >&2
    exit 1
fi

# Verify '🎉' is now at the top of history
post_copy_hist=$("$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" history)
first_hist=$(printf '%s\n' "$post_copy_hist" | head -n 1)
if [[ "$first_hist" != "🎉" ]]; then
    echo "FAIL: expected top history item '🎉', got '$first_hist'" >&2
    exit 1
fi

# Test copy from stdin
printf '🔥' | PATH="$mock_bin:$PATH" "$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" copy
copied_val=$(cat "$copied_file")
if [[ "$copied_val" != "🔥" ]]; then
    echo "FAIL: expected '🔥' from stdin, got '$copied_val'" >&2
    exit 1
fi

# Verify '🔥' is now #1, and '🎉' is #2
post_copy_hist=$("$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" history)
first_hist=$(printf '%s\n' "$post_copy_hist" | head -n 1)
second_hist=$(printf '%s\n' "$post_copy_hist" | sed -n '2p')
if [[ "$first_hist" != "🔥" || "$second_hist" != "🎉" ]]; then
    echo "FAIL: expected history order 🔥 then 🎉, got $first_hist then $second_hist" >&2
    exit 1
fi

# Test record directly and deduplication
"$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" record "🎉"
post_copy_hist=$("$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" history)
first_hist=$(printf '%s\n' "$post_copy_hist" | head -n 1)
second_hist=$(printf '%s\n' "$post_copy_hist" | sed -n '2p')
if [[ "$first_hist" != "🎉" || "$second_hist" != "🔥" ]]; then
    echo "FAIL: expected deduplicated history order 🎉 then 🔥, got $first_hist then $second_hist" >&2
    exit 1
fi

# Test capacity limit: max 16 items, oldest evicted
# We already have 🎉 and 🔥. Let's record 16 more unique emojis:
overflow_emojis=("1️⃣" "2️⃣" "3️⃣" "4️⃣" "5️⃣" "6️⃣" "7️⃣" "8️⃣" "9️⃣" "🔟" "🇦" "🇧" "🇨" "🇩" "🇪" "🇫")
for emo in "${overflow_emojis[@]}"; do
    "$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" record "$emo"
done

cap_hist=$("$REPO_ROOT/src/core/backend/desktop/emoji_ctl.sh" history)
cap_count=$(printf '%s\n' "$cap_hist" | wc -l)
if [[ "$cap_count" -ne 16 ]]; then
    echo "FAIL: expected capped history count 16, got $cap_count" >&2
    exit 1
fi

# Newest item must be 🇫 (last inserted)
cap_first=$(printf '%s\n' "$cap_hist" | head -n 1)
if [[ "$cap_first" != "🇫" ]]; then
    echo "FAIL: expected newest item 🇫 at head of history, got $cap_first" >&2
    exit 1
fi

# Oldest items (🎉 and 🔥) must have been evicted
if grep -q "🎉" <<< "$cap_hist" || grep -q "🔥" <<< "$cap_hist"; then
    echo "FAIL: expected oldest items (🎉, 🔥) to be evicted from history cap" >&2
    exit 1
fi

# 4. Test emoji_menu.sh --help and --list and --history
"$REPO_ROOT/src/core/facade/emoji_menu.sh" --help >/dev/null || {
    echo "FAIL: emoji_menu.sh --help failed" >&2
    exit 1
}

list_output=$("$REPO_ROOT/src/core/facade/emoji_menu.sh" --list)
if [[ "$(printf '%s\n' "$list_output" | wc -l)" -ne 2 ]]; then
    echo "FAIL: emoji_menu.sh --list did not return expected fixture lines" >&2
    exit 1
fi

history_output=$("$REPO_ROOT/src/core/facade/emoji_menu.sh" --history)
if [[ "$(printf '%s\n' "$history_output" | wc -l)" -ne 16 ]]; then
    echo "FAIL: emoji_menu.sh --history did not return 16 history lines" >&2
    exit 1
fi

# 5. Test Classic mode routing for emoji_menu.sh
ipc_log="$test_dir/ipc.log"
classic_log="$test_dir/classic.log"

cat > "$mock_bin/rofi" <<MOCK_ROFI
#!/usr/bin/env bash
printf 'rofi: %s\n' "\$*" >> "$classic_log"
MOCK_ROFI
chmod +x "$mock_bin/rofi"

cat > "$mock_bin/qs" <<MOCK_QS
#!/usr/bin/env bash
printf 'qs: %s\n' "\$*" >> "$ipc_log"
MOCK_QS
chmod +x "$mock_bin/qs"

# Test classic mode
mkdir -p "$test_dir/home/.local/state/hakuspace/state"
state_dir="$test_dir/home/.local/state/hakuspace/state"
printf 'classic' > "$state_dir/[shell].backend"

HOME="$test_dir/home" PATH="$mock_bin:$PATH" "$REPO_ROOT/src/core/facade/emoji_menu.sh"
if ! grep -q "rofi: -modi emoji -show emoji" "$classic_log"; then
    echo "FAIL: emoji_menu.sh did not invoke rofi in classic mode" >&2
    exit 1
fi

# Test Hikai mode for emoji_menu.sh
printf 'hikai' > "$state_dir/[shell].backend"
HOME="$test_dir/home" PATH="$mock_bin:$PATH" "$REPO_ROOT/src/core/facade/emoji_menu.sh"
if ! grep -q "actionMenu openDefault emoji" "$ipc_log"; then
    echo "FAIL: emoji_menu.sh did not call quickshell actionMenu openDefault emoji in hikai mode" >&2
    exit 1
fi

# 6. Test launcher.sh emoji in Hikai mode
HOME="$test_dir/home" PATH="$mock_bin:$PATH" "$REPO_ROOT/src/core/util/launcher.sh" emoji
if ! grep -q "launcher open emoji" "$ipc_log"; then
    echo "FAIL: launcher.sh emoji did not call quickshell launcher open emoji in hikai mode" >&2
    exit 1
fi

echo "All emoji backend, facade, and launcher tests passed!"
