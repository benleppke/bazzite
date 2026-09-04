#!/bin/bash

set -ouex pipefail

echo "#######################################################################################################################"
echo "Running gnome-shell script..."

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
dnf5 install -y --enablerepo=benleppke nautilus-custom-icon-name
