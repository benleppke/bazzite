#!/usr/bin/env bash
set -e
shopt -s nullglob

# Themes to create variants for
BASE_THEMES=("Papirus-Dark" "Papirus-Light")
TARGET_BASE="/usr/share/icons"

COLORS=(blue teal green yellow orange red pink violet grey)
SOURCE_SIZES=(22x22 24x24 32x32 48x48 64x64)
SIZE_SYMLINKS=(
  "16x16@2x=16x16"
  "18x18@2x=18x18"
  "22x22@2x=22x22"
  "24x24@2x=24x24"
  "32x32@2x=32x32"
  "48x48@2x=48x48"
  "64x64@2x=64x64"
  "96x96=64x64"
  "128x128=64x64"
)

process_size() {
  local SRC_SIZE="$1"
  local DEST_SIZE="$2"
  local SRC_DIR="/usr/share/icons/Papirus/${SRC_SIZE}/places"
  local DEST_DIR="$TARGET_PATH/${DEST_SIZE}/places"

  echo "  - Linking $DEST_SIZE from $SRC_SIZE"
  mkdir -p "$DEST_DIR"

  for icon in "$SRC_DIR"/*-"${COLOR}"-*.svg "$SRC_DIR"/*-"${COLOR}".svg; do
    base_name=$(basename "$icon" | sed "s/-${COLOR}\(-\|\.svg\)/\1/")
    target_icon="$DEST_DIR/$base_name"
    echo "    • $base_name → $icon"
    ln -sf "$icon" "$target_icon"
  done
}

for BASE_THEME in "${BASE_THEMES[@]}"; do
  BASE_PATH="/usr/share/icons/$BASE_THEME"

  for COLOR in "${COLORS[@]}"; do
    NEW_THEME="${BASE_THEME}-${COLOR^}"
    TARGET_PATH="$TARGET_BASE/$NEW_THEME"
    echo "==> Creating theme: $NEW_THEME"

    mkdir -p "$TARGET_PATH"
    cp "$BASE_PATH/index.theme" "$TARGET_PATH/index.theme"
    sed -i "s/^Name=.*/Name=$NEW_THEME/" "$TARGET_PATH/index.theme"
    sed -i "s/^Inherits=.*/Inherits=$BASE_THEME/" "$TARGET_PATH/index.theme"

    # Real-size directories
    for SIZE in "${SOURCE_SIZES[@]}"; do
      process_size "$SIZE" "$SIZE"
    done

    # Symlinked sizes
    for mapping in "${SIZE_SYMLINKS[@]}"; do
      process_size "${mapping##*=}" "${mapping%%=*}"
    done
  done
done

echo "Themes created successfully."
