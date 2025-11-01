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

# blur-my-shell - enable GNOME 49 support

FILE="/usr/share/gnome-shell/extensions/blur-my-shell@aunetx/metadata.json"

tmp=$(mktemp)
if jq -e '.["shell-version"] | index("49")' "$FILE" >/dev/null; then
    echo "GNOME 49 support already present, no changes made."
else
    tmp=$(mktemp)
    jq '.["shell-version"] += ["49"]' "$FILE" > "$tmp"
    mv "$tmp" "$FILE"
    chmod 644 "$FILE"
    echo "GNOME 49 support added to $FILE."
fi