#!/bin/bash

echo "Running core-packages script..."
set -ouex pipefail

# Zsh
dnf5 install -y \
  zsh \
  zsh-autosuggestions

# Wine
dnf5 install -y \
  wine-mono

# Add rpmfusion repositories
dnf5 install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install microsoft fonts
dnf5 install -y \
  msttcore-fonts-installer

# Codium
dnf5 install -y \
  --enablerepo=vscodium \
    codium

# Gnome Initial Setup
dnf5 install -y \
  gnome-initial-setup