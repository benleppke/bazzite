#!/bin/bash

set -ouex pipefail

echo "#######################################################################################################################"
echo "Running gnome-extensions script..."

extensions_file="/ctx/extensions.txt"
install_dir="/usr/share/gnome-shell/extensions"
gnome_version=$(rpm -q gnome-shell --qf '%{VERSION}\n' | cut -d. -f1)

echo "Detected GNOME Shell version: $gnome_version"

while IFS= read -r uuid; do
  # Skip empty lines or comments
  [[ -z "$uuid" || "$uuid" =~ ^# ]] && continue

  echo "Processing $uuid ..."

  # Fetch extension metadata
  metadata=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}")

  # Extract pk for this gnome version
  version_pk=$(jq -r ".shell_version_map[\"$gnome_version\"].pk" <<<"$metadata")
  version_tag=$(jq -r ".shell_version_map[\"$gnome_version\"].version" <<<"$metadata")

  if [[ "$version_pk" == "null" || "$version_tag" == "null" ]]; then
    echo "❌ No matching version for GNOME $gnome_version found for $uuid"
    exit 1
  fi

  echo "Found version $version_tag (pk=$version_pk) for GNOME $gnome_version"

  # Download extension zip
  tmpfile=$(mktemp /tmp/gnome-ext-XXXX.zip)
  curl -fsSL \
    -o "$tmpfile" \
    "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${version_pk}"

  # Extract to system dir
  unzip -q -o "$tmpfile" -d "$install_dir/$uuid"

  rm -f "$tmpfile"
  echo "✅ Installed $uuid into $install_dir"
done < "$extensions_file"

# --- gnome-rounded-blur ---
echo "Fetching gnome-rounded-blur..."
GITLAB_PROJECT_ID="82111358"

fedora=""
if rpm -q fedora-release &>/dev/null; then
  fedora=$(rpm -q --qf "%{VERSION}" fedora-release | cut -d'.' -f1)
fi
if [ -z "$fedora" ]; then
  fedora=$(grep -oP 'VERSION_ID="?\K[^" ]+' /etc/os-release | cut -d'.' -f1)
fi

TAG="gnome-rounded-blur-f${fedora}-gnome${gnome_version}"
echo "Tag: $TAG"

curl -sfL -o /tmp/gnome-rounded-blur.zip \
  "https://gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID}/packages/generic/gnome-rounded-blur/${TAG}/gnome-rounded-blur.zip"

unzip -o /tmp/gnome-rounded-blur.zip -d /tmp/gnome-rounded-blur
cp -a /tmp/gnome-rounded-blur/usr/* /usr/
/sbin/ldconfig

echo "✅ gnome-rounded-blur installed for Fedora $fedora / GNOME $gnome_version"
