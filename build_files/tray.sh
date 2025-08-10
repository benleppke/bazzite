#!/usr/bin/env bash
set -e

dnf5 install -y \
  python3-meson-python \
  meson \
  ninja-build \
  gobject-introspection-devel \
  librsvg2-tools

git clone https://github.com/bil-elmoussaoui/Hardcode-Tray.git

cd Hardcode-Tray

meson setup builddir --prefix=/usr

ninja -C builddir install

hardcode-tray --conversion-tool RSVGConvert --size 22 --theme Papirus
