#!/bin/bash

set -ouex pipefail

echo "#######################################################################################################################"
echo "Running pre-build script..."

# Workaround for Terra Mesa GPG key
if [ -f /etc/yum.repos.d/terra-mesa.repo ]; then
    sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/terra-mesa.repo
fi

# Avoid GPG errors when dnf5 tries to import keys
export GNUPGHOME=/tmp/gnupg
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# Use a temporary dnf5 cache to prevent including /var/lib/dnf in the final image
export DNF5_SYSTEM_CACHEDIR=/tmp/dnf-cache
