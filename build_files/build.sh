#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

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

#### Example for enabling a System Unit File

systemctl enable podman.socket
