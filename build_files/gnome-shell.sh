#!/bin/bash

echo "Running gnome-shell script..."
set -ouex pipefail

# Pop Shell extensions and sound/icon themes
dnf5 install -y \
  gnome-shell-extension-pop-shell \
  gnome-shell-extension-pop-shell-shortcut-overrides \
  ocean-sound-theme \
  papirus-icon-theme-dark \
  papirus-icon-theme-light

# Additional Papirus Folder Icons and Nautilus Custom Icon Name
shopt -s nullglob

echo "Installing Additional Papirus Folder Icons..."
git clone https://gitlab.com/benleppke/papirus-folder-icons.git --depth 1

./papirus-folder-icons/setup.sh --install --system --force

echo "Installing Additional Papirus Icons..."
git clone https://gitlab.com/benleppke/papirus-icons.git --depth 1

./papirus-icons/setup.sh --install --system --force

echo "Installing Nautilus Custom Icon Name..."
git clone https://gitlab.com/benleppke/nautilus-custom-icon-name.git --depth 1

./nautilus-custom-icon-name/setup.sh --install --system --force

# Desktop files to hide
DESKTOP_FILES="\
/usr/share/applications/discourse.desktop \
/usr/share/applications/waydroid-container-restart.desktop"

# Loop through each file in the list
for FILE in $DESKTOP_FILES; do
  # 1. Check if the file exists
  if [[ -f "$FILE" ]]; then
    echo "Processing: $FILE"

    if grep -q '^NoDisplay=' "$FILE"; then
      if grep -q '^NoDisplay=true' "$FILE"; then
      else
        # Modify existing line
        sed -i '/^NoDisplay=/c\NoDisplay=true' "$FILE"
      fi

    else
      # Add a new line
      sed -i '/^\[Desktop Entry\]/aNoDisplay=true' "$FILE"
    fi

  else
    echo "Skipping: $FILE - File not found."
  fi
done
