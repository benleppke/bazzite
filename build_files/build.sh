#!/bin/bash

set -ouex pipefail

# Avoid GPG errors when dnf5 tries to import keys
export GNUPGHOME=/tmp/gnupg
mkdir -p "$GNUPGHOME"

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
  papirus-icon-theme-dark

dnf5 install -y \
  android-tools \
  yt-dlp

dnf5 install -y \
  --enablerepo=vscodium \
    codium

systemctl enable podman.socket

systemctl enable docker.socket

brew install \
  bat \
  eza \
  gh \
  glab \
  direnv
