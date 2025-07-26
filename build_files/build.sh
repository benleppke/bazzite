#!/bin/bash

set -ouex pipefail

### Install packages

dnf5 install -y \
  zsh \
  zsh-autosuggestions

dnf5 install -y \
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
  yt-dlp \
  tmux

dnf5 copr enable tcg/vscodium
dnf5 install -y codium
dnf5 copr disable tcg/vscodium

systemctl enable podman.socket

systemctl enable docker.socket
