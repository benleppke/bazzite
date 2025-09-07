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

# Codium
dnf5 install -y \
  --enablerepo=vscodium \
    codium

# Gnome Initial Setup
dnf5 install -y \
  gnome-initial-setup