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

# Install Microsoft fonts
dnf5 install -y \
  https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm

# Codium
dnf5 install -y \
  --enablerepo=vscodium \
    codium

# Gnome Initial Setup
dnf5 install -y \
  gnome-initial-setup