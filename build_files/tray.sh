#!/usr/bin/env bash
set -e

git clone https://github.com/bil-elmoussaoui/Hardcode-Tray.git

cd Hardcode-Tray

meson builddir --prefix=/usr

ninja -C builddir install

hardcode-tray --conversion-tool RSVGConvert --size 22 --theme Papirus
