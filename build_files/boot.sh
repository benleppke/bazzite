#!/bin/bash

set -ouex pipefail

echo "#######################################################################################################################"
echo "Running boot script..."

# Get kernel version
KERNEL_VERSION="$(dnf5 repoquery --installed --queryformat='%{evr}.%{arch}' kernel)"

export DRACUT_NO_XATTR=1  # suppress xattr warnings

# Rebuild initramfs
/usr/bin/dracut \
  --no-hostonly \
  --kver "$KERNEL_VERSION" \
  --reproducible \
  --zstd \
  -v \
  --add ostree \
  -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

chmod 0600 "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

dnf5 install -y plymouth-plugin-script --disableexcludes=all
