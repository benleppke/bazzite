#!/bin/bash
set -euxo pipefail

build_image="fedora:42"
build_dir="/build"
output_dir="/ctx/output"

if [ ! -d nautilus-folder-icons ]; then
  git clone https://github.com/bilelmoussaoui/nautilus-folder-icons.git
fi

podman run --rm \
  -v "$(pwd)/nautilus-folder-icons":$build_dir:Z \
  -v "$output_dir":/output:Z \
  $build_image /bin/bash -c "
    dnf install -y meson ninja-build gcc python3-devel gettext pygobject3-devel glib2-devel gtk3-devel &&
    cd $build_dir &&
    meson setup builddir --prefix=/usr -Dfile_manager=nautilus &&
    ninja -C builddir install DESTDIR=/output
"
