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

# Use a persistent dnf5 cache on the /var/cache cache mount to keep it out of
# the final image and off the tmpfs /tmp (which would put it in host RAM)
export DNF5_SYSTEM_CACHEDIR=/var/cache/libdnf5
