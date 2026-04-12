#!/bin/bash

set -ouex pipefail

echo "#######################################################################################################################"
echo "Running core-packages script..."

# Zsh
dnf5 install -y \
  zsh \
  zsh-autosuggestions

# Wine
# dnf5 install -y \
#   dotnet-sdk-8.0

# Install Microsoft fonts
dnf5 -y copr enable dawid/better_fonts \
 && dnf5 install -y --enablerepo=dawid/better_fonts mscorefonts

# Codium
dnf5 install -y \
  --enablerepo=vscodium \
    codium

# Firefox PWA
dnf5 install -y \
  --enablerepo=firefoxpwa \
    firefoxpwa

# Gparted
dnf5 install -y \
  gparted

# Gnome Initial Setup
dnf5 install -y \
  gnome-initial-setup
