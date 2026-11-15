#!/usr/bin/env bash
# Generate the netboot.xyz iPXE menu for the published live ISOs.
#
# Usage: netboot_menu.sh <index.json>
#
# The menu is rebuilt from bazzite/latest/index.json on every publish run, so
# netboot.xyz only has to chain to bazzite/latest/menu.ipxe once. Flavours and
# releases come and go with the index; nothing here needs editing.
#
# iPXE executes a script linearly, so all menu items and the `choose` command
# must be emitted before any `:label` block.
#
# iPXE variables (${space}, ${target}) are emitted literally on purpose.
# shellcheck disable=SC2016
set -euo pipefail

index="${1:-}"
if [[ -z "$index" || ! -f "$index" ]]; then
    echo "usage: $0 <index.json>" >&2
    exit 1
fi

base="$(jq -r '.base_url' "$index")"
generated="$(jq -r '.generated_at // "unknown"' "$index")"

display_name() {
    case "$1" in
        bazzite-gnome)        echo "Bazzite GNOME" ;;
        bazzite-gnome-nvidia) echo "Bazzite GNOME NVIDIA" ;;
        bazzite-deck-gnome)   echo "Bazzite Deck GNOME" ;;
        *)                    echo "$1" ;;
    esac
}

# Releases are the non-null date entries, newest first. Deriving the latest
# date from them (instead of trusting .latest) keeps the menu correct even if
# the index holds stale or null entries for a flavour that was never built.
releases_for() {
    jq -r --arg f "$1" '
        .flavors[$f].releases
        | to_entries
        | map(select(.value != null) | .key)
        | sort
        | reverse
        | .[]
    ' "$index" 2>/dev/null || true
}

flavors=()
add_flavor() {
    local flavor="$1"
    [[ -n "$flavor" ]] || return 0
    if [[ -n "$(releases_for "$flavor" | head -1)" ]]; then
        flavors+=("$flavor")
    fi
}

# Preferred menu order; anything else follows in index order.
for flavor in bazzite-gnome bazzite-gnome-nvidia bazzite-deck-gnome; do
    add_flavor "$flavor"
done
while read -r flavor; do
    case " ${flavors[*]} " in
        *" $flavor "*) ;;
        *) add_flavor "$flavor" ;;
    esac
done < <(jq -r '.flavors | keys[]' "$index")

if [[ ${#flavors[@]} -eq 0 ]]; then
    cat <<'EOF'
#!ipxe
echo No Bazzite releases are published yet.
exit 0
EOF
    exit 0
fi

items="$(mktemp)"
older_items="$(mktemp)"
labels="$(mktemp)"
trap 'rm -f "$items" "$older_items" "$labels"' EXIT

default=""
for flavor in "${flavors[@]}"; do
    latest="$(releases_for "$flavor" | head -1)"
    label="latest_${flavor//-/_}"
    printf 'item %s ${space} %s (%s)\n' \
        "$label" "$(display_name "$flavor")" "$latest" >> "$items"
    {
        printf ':%s\n' "$label"
        printf 'set nb %s/latest/netboot/%s\n' "$base" "$flavor"
        printf 'goto boot\n\n'
    } >> "$labels"
    [[ -n "$default" ]] || default="$label"

    # Older releases: everything except the latest, which is a top-level item.
    count="$(releases_for "$flavor" | wc -l)"
    if [[ $count -gt 1 ]]; then
        printf 'item --gap %s:\n' "$(display_name "$flavor")" >> "$older_items"
    fi
    releases_for "$flavor" | tail -n +2 | while read -r date; do
        label="r_${date//-/_}_${flavor//-/_}"
        printf 'item %s ${space} %s (%s)\n' \
            "$label" "$(display_name "$flavor")" "$date" >> "$older_items"
        {
            printf ':%s\n' "$label"
            printf 'set nb %s/live/%s/netboot/%s\n' "$base" "$date" "$flavor"
            printf 'goto boot\n\n'
        } >> "$labels"
    done
done

cat <<EOF
#!ipxe
# Bazzite live ISOs, generated ${generated}
set bzb ${base}
isset space || set space --

:start
menu Bazzite live
item --gap Latest release:
EOF

cat "$items"

echo "item --gap"
if [[ -s "$older_items" ]]; then
    echo 'item older ${space} Older releases...'
fi
echo 'item back ${space} Back to netboot.xyz'
echo "choose --default ${default} target || goto back"
echo 'goto ${target}'

if [[ -s "$older_items" ]]; then
    cat <<'EOF'

:older
menu Bazzite older releases
EOF
    cat "$older_items"
    cat <<'EOF'
item --gap
item back ${space} Back
choose target || goto start
goto ${target}
EOF
fi

cat <<'EOF'

:boot
imgfree
kernel ${nb}/vmlinuz initrd=initrd.img root=live:${nb}/squashfs.img rd.live.image rd.neednet=1 ip=dhcp enforcing=0 quiet
initrd ${nb}/initrd.img
boot

:back
exit 0

EOF

cat "$labels"
