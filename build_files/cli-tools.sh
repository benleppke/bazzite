#!/bin/bash

set -ouex pipefail

# CLI tools
dnf5 install -y \
  android-tools \
  htop \
  ncdu \
  yt-dlp

# Don't show cli tools in the application menu
find /usr/share/applications/ -maxdepth 1 -type f \
    -name "*htop.desktop" -o -name "*ncdu.desktop" | \
    while read -r file; do \
        sed -i -e '$iNoDisplay=true' "$file"; \
    done