#!/usr/bin/env bash
set -e
shopt -s nullglob

git clone https://gitlab.com/benleppke/papirus-folder-icons.git --depth 1

./papirus-folder-icons/setup.sh All

git clone https://gitlab.com/benleppke/nautilus-custom-icon-name.git --depth 1

./nautilus-custom-icon-name/setup.sh --install
