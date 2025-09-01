#!/usr/bin/env bash
set -ex
shopt -s nullglob

echo "Installing Additional Papirus Folder Icons..."
git clone https://gitlab.com/benleppke/papirus-folder-icons.git --depth 1

./papirus-folder-icons/setup.sh All

echo "Installing Nautilus Custom Icon Name..."
git clone https://gitlab.com/benleppke/nautilus-custom-icon-name.git --depth 1

./nautilus-custom-icon-name/setup.sh --install --system --force
