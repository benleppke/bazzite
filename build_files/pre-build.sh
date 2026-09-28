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

# Redirect dnf5's metadata/download cache into the build's tmpfs /tmp so it is
# always fresh and never baked into the image or the persistent /var/cache.
mkdir -p /etc/dnf/libdnf5.conf.d
printf '[main]\nsystem_cachedir=/tmp/dnf-cache\n' > /etc/dnf/libdnf5.conf.d/99-build.conf
