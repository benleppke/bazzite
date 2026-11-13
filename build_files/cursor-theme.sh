#!/bin/bash

set -ouex pipefail

echo "#######################################################################################################################"
echo "Running cursor-theme script..."

# Bibata cursor themes with the SVG set GNOME Shell 51 renders from.
# Built by https://github.com/palexdev/bibata-cursor-svg from upstream
# Bibata v2.0.7. The archive ships both `cursors` (XCursor bitmaps) and
# `cursors_scalable` (SVG), so apps and the shell agree on the pointer.
BIBATA_VERSION="v2.0.7"
BIBATA_THEME="Bibata-Modern-Classic"
BIBATA_SHA256="28f811fe09e98e7b2a2292adab47ebfbe2c94a8ec70068ee0aef0a7e0451d429"

archive="/tmp/${BIBATA_THEME}.tar.xz"
curl -fsSL -o "$archive" \
  "https://github.com/palexdev/bibata-cursor-svg/releases/download/${BIBATA_VERSION}/${BIBATA_THEME}.tar.xz"
echo "${BIBATA_SHA256}  ${archive}" | sha256sum -c -

tar -xJf "$archive" -C /usr/share/icons
rm -f "$archive"
