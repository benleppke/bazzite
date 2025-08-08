#!/usr/bin/env bash

set -e

# Base icon theme
BASE_THEME="Papirus-Dark"
BASE_PATH="/usr/share/icons/$BASE_THEME"
TARGET_BASE="/usr/share/icons/"

# Colors to create variants for
COLORS=(blue teal green yellow orange red pink violet grey)

# Source folder for folder icons
SOURCE_SIZES=(22x22 24x24 32x32 48x48 64x64)

# Sizes that should symlink to another size
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

for COLOR in "${COLORS[@]}"; do
  NEW_THEME="${BASE_THEME}-${COLOR^}"
  TARGET_PATH="$TARGET_BASE/$NEW_THEME"
  echo "==> Creating theme: $NEW_THEME"

  mkdir -p "$TARGET_PATH"
  echo "  - Copying index.theme to $TARGET_PATH"
  cp "$BASE_PATH/index.theme" "$TARGET_PATH/index.theme"
  sed -i "s/^Name=.*/Name=$NEW_THEME/" "$TARGET_PATH/index.theme"
  sed -i "s/^Inherits=.*/Inherits=$BASE_THEME/" "$TARGET_PATH/index.theme"

  # Handle real-size directories
  for SIZE in "${SOURCE_SIZES[@]}"; do
    SRC_DIR="/usr/share/icons/Papirus/${SIZE}/places"
    DEST_DIR="$TARGET_PATH/${SIZE}/places"
    echo "  - Linking icons for size: $SIZE"

    mkdir -p "$DEST_DIR"

    for icon in "$SRC_DIR"/*-${COLOR}-*.svg "$SRC_DIR"/folder-${COLOR}.svg; do
      base_name=$(basename "$icon" | sed "s/folder-${COLOR}-/folder-/")
      target_icon="$DEST_DIR/$base_name"

      echo "    • $base_name → $icon"
      ln -sf "$icon" "$target_icon"
    done
  done

  # Handle symlinked sizes
  for mapping in "${SIZE_SYMLINKS[@]}"; do
    SIZE="${mapping%%=*}"
    SRC_SIZE="${mapping##*=}"

    SRC_DIR="/usr/share/icons/Papirus/${SRC_SIZE}/places"
    DEST_DIR="$TARGET_PATH/${SIZE}/places"

    echo "  - Linking $SIZE from $SRC_SIZE"

    mkdir -p "$DEST_DIR"

    for icon in "$SRC_DIR"/folder-${COLOR}-*.svg "$SRC_DIR"/folder-${COLOR}.svg; do
      base_name=$(basename "$icon" | sed "s/folder-${COLOR}-/folder-/")
      target_icon="$DEST_DIR/$base_name"

      echo "    • $base_name → $icon"
      ln -sf "$icon" "$target_icon"
    done
  done
done

echo "$BASE_THEME themes created successfully."
