#!/bin/bash

set -ouex pipefail

# Avoid GPG errors when dnf5 tries to import keys
export GNUPGHOME=/tmp/gnupg
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# Use a temporary dnf5 cache to prevent including /var/lib/dnf in the final image
export DNF5_SYSTEM_CACHEDIR=/tmp/dnf-cache

### Install packages

dnf5 install -y \
  zsh \
  zsh-autosuggestions

dnf5 install -y \
  --enablerepo=docker-ce \
  containerd.io \
  docker-buildx-plugin \
  docker-ce \
  docker-ce-cli \
  docker-compose-plugin

dnf5 install -y \
  gnome-shell-extension-pop-shell \
  gnome-shell-extension-pop-shell-shortcut-overrides \
  ocean-sound-theme \
  papirus-icon-theme-dark \
  papirus-icon-theme-light

dnf5 install -y\
  wine-mono

dnf5 install -y \
  android-tools \
  htop \
  ncdu \
  yt-dlp

# Don't show cli tools in the application menu
find /usr/share/applications/ -maxdepth 1 -type f \
    -name "*htop.desktop" -o -name "*ncdu.desktop" | \
    while read -r file; do \
        sed -i -e '$iNoDisplay=true' "$file"; \
    done

dnf5 install -y \
  --enablerepo=vscodium \
    codium

cat > /usr/lib/sysusers.d/docker.sysusers <<EOF
g docker - "Docker Group"
EOF

systemctl enable docker.socket

dnf5 install -y \
  gnome-initial-setup
