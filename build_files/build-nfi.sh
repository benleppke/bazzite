#!/bin/bash
set -euxo pipefail

build_dir="/build"

if [ ! -d nautilus-folder-icons ]; then
  git clone https://github.com/bilelmoussaoui/nautilus-folder-icons.git
fi

dnf install -y meson ninja-build gcc python3-devel gettext python3-gobject-devel glib2-devel gtk3-devel &&
cd $build_dir &&
meson setup builddir --prefix=/usr -Dfile_manager=nautilus &&
DESTDIR=/output ninja -C builddir install
