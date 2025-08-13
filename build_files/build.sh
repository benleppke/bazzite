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
  papirus-icon-theme-light \
  plymouth-plugin-script

dnf5 install -y \
  android-tools \
  htop \
  yt-dlp

dnf5 install -y \
  --enablerepo=vscodium \
    codium

curl -fsSL \
  https://gitlab.com/benleppke/nautilus-custom-icon-name/-/raw/main/custom-icon-name.py \
  -o /usr/share/nautilus-python/extensions/custom-icon-name.py

groupadd -f docker

systemctl enable docker.socket

dnf5 install -y \
  gnome-initial-setup
