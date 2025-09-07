#!/bin/bash

echo "Running pre-build script..."
set -ouex pipefail

# Avoid GPG errors when dnf5 tries to import keys
export GNUPGHOME=/tmp/gnupg
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# Use a temporary dnf5 cache to prevent including /var/lib/dnf in the final image
export DNF5_SYSTEM_CACHEDIR=/tmp/dnf-cache
