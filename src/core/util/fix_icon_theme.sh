#!/usr/bin/env bash
set -eo pipefail

# This script fixes icon themes by creating symlinks for certain icons that may be missing or incorrectly named.

ICONS_ROOT="${HOME}/.icons"
[ -d "$ICONS_ROOT" ] || { echo "Directory not found: $ICONS_ROOT"; exit 1; }

# Mapping: source_icon -> target_icon
declare -A MAP=(
  [application-x-shellscript]=text-x-shellscript
  [gnome-mime-application-x-shellscript]=text-x-shellscript
  [application-x-python]=text-x-python
  [application-x-perl]=text-x-perl
  [application-x-executable-script]=application-x-executable
  [application-x-ruby]=text-x-ruby
  [application-x-lua]=text-x-lua
)

fix_theme() {
  local theme_dir="${1%/}"
  local theme_name="${theme_dir##*/}"
  local changed=0

  for src in "${!MAP[@]}"; do
    local dst="${MAP[$src]}"
    [ "$src" = "$dst" ] && continue

    while IFS= read -r -d '' f; do
      local ext="${f##*.}"
      local dir="${f%/*}"
      local target="${dir}/${dst}.${ext}"
      local base_f="${f##*/}"

      # If target is already a regular file and not a symlink, keep it
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        continue
      fi

      # If target is a symlink pointing to the correct file, skip
      if [ -L "$target" ] && [ "$(readlink "$target")" = "$base_f" ]; then
        continue
      fi

      # Create or fix the symlink in the target directory
      (cd "$dir" && ln -sf "$base_f" "${dst}.${ext}")
      echo "  + ${theme_name}: created/fixed ${dst}.${ext} -> ${base_f}"
      changed=1
    done < <(find "$theme_dir" -not -type d -iname "${src}.*" -print0 2>/dev/null)
  done

  # Cập nhật cache cho theme
  if gtk-update-icon-cache -f -t "$theme_dir" >/dev/null 2>&1; then
    if [ "$changed" -eq 1 ]; then
      echo "✓ Fixed & cache rebuilt: $theme_name"
    else
      echo "✓ Cache rebuilt (no new symlinks): $theme_name"
    fi
  else
    echo "✗ Cache rebuild failed (check permissions/index.theme): $theme_name"
  fi
}

for theme_dir in "$ICONS_ROOT"/*/; do
  [ -d "$theme_dir" ] || continue
  # Chỉ xử lý các thư mục là icon theme hợp lệ (có chứa index.theme)
  if [ -f "$theme_dir/index.theme" ]; then
    fix_theme "$theme_dir"
  else
    echo "⚠ Skipping ${theme_dir##*/} (no index.theme found)"
  fi
done

echo "Finished processing icon themes in $ICONS_ROOT"