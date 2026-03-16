#!/bin/bash

set -ouex pipefail

echo "#######################################################################################################################"
echo "Running core-packages script..."

# Zsh
dnf5 install -y \
  zsh \
  zsh-autosuggestions

# Silence global profile.d sourcing in zsh to prevent terminal escape sequences
sed -i '/\. $i/ s|\. \$i|\. \$i >/dev/null 2>\&1|' /etc/zshrc

# Install Microsoft fonts
dnf5 -y copr enable dawid/better_fonts \
 && dnf5 install -y --enablerepo=dawid/better_fonts mscorefonts

# Codium
dnf5 install -y \
  --enablerepo=vscodium \
    codium

# Gparted
dnf5 install -y \
  gparted

# Gnome Initial Setup
dnf5 install -y \
  gnome-initial-setup
