#!/bin/bash

set -ouex pipefail

echo "#######################################################################################################################"
echo "Running gnome-extensions script..."

extensions_file="/ctx/extensions.txt"
force_file="/ctx/force-incompatible"
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

  # Check for compatibility
  if [[ "$version_pk" == "null" ]]; then
    echo "⚠️ No compatible version found for $uuid on GNOME $gnome_version"
    
    if [[ -f "$force_file" ]]; then
      echo "FORCE sentinel found. Attempting to fetch latest available version instead..."
      # Fallback: Grab the PK of the highest version number available in the metadata map
      version_pk=$(jq -r '.shell_version_map | to_entries | sort_by(.key | tonumber) | last | .value.pk' <<<"$metadata")
      version_tag="LATEST_FALLBACK"
    else
      echo "❌ Compatibility check failed and $force_file is not present. Failing build."
      exit 1
    fi
  fi

  echo "Found version $version_tag (pk=$version_pk) for GNOME $gnome_version"

  # Download extension zip
  tmpfile=$(mktemp /tmp/gnome-ext-XXXX.zip)
  curl -fsSL \
    -o "$tmpfile" \
    "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${version_pk}"

  # Extract to system dir
  mkdir -p "$install_dir/$uuid"
  unzip -q -o "$tmpfile" -d "$install_dir/$uuid"

  rm -f "$tmpfile"
  echo "✅ Installed $uuid into $install_dir"
done < "$extensions_file"
