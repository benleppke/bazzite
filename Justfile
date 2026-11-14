set dotenv-load

export image_name := env("IMAGE_NAME", "bazzite")
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")
export titanoboa_runtime_image := env("TITANOBOA_RUNTIME_IMAGE", "quay.io/fedora/fedora:latest")
export IMAGE_REGISTRY := env("IMAGE_REGISTRY", "ghcr.io/benleppke")

# Rootful build storage and artifacts. Override BUILD_ROOT in .env to keep
# large container images and ISOs off the primary disk.
export BUILD_ROOT := env("BUILD_ROOT", justfile_directory() + "/build")
export PODMAN_STORAGE_CONF := BUILD_ROOT + "/containers/storage.conf"
export PODMAN_GRAPHROOT := BUILD_ROOT + "/containers/storage"
export BUILD_TMP_DIR := BUILD_ROOT + "/tmp"
export BUILD_OUTPUT_DIR := BUILD_ROOT + "/output"

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -maxdepth 0 -type d -print0 | xargs -0 rm -rf
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -rf output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# Set up rootful Podman storage and build output on BUILD_ROOT
[confirm("Set up rootful Podman storage in BUILD_ROOT?")]
[group('Utility')]
setup-build-dir:
    #!/usr/bin/env bash
    set -euo pipefail

    BUILD_ROOT="{{ BUILD_ROOT }}"
    STORAGE_CONF="{{ PODMAN_STORAGE_CONF }}"
    GRAPHROOT="{{ PODMAN_GRAPHROOT }}"
    BUILD_TMP="{{ BUILD_TMP_DIR }}"
    BUILD_OUTPUT="{{ BUILD_OUTPUT_DIR }}"

    if [[ -z "${BUILD_ROOT}" || "${BUILD_ROOT}" == "/" ]]; then
        echo "Error: refusing to use BUILD_ROOT=${BUILD_ROOT}" >&2
        exit 1
    fi

    sudo mkdir -p "${GRAPHROOT}" "${BUILD_TMP}" "${BUILD_OUTPUT}"

    if [[ ! -f "${STORAGE_CONF}" ]]; then
        {
            echo "[storage]"
            echo 'driver = "overlay"'
            echo "graphroot = \"${GRAPHROOT}\""
            echo 'runroot = "/run/containers/storage-ssd"'
        } | sudo tee "${STORAGE_CONF}" >/dev/null
    fi

    # Label the storage like the default rootful graphroot. This is idempotent.
    if ! sudo semanage fcontext -l 2>/dev/null | grep -Fq "${GRAPHROOT}"; then
        sudo semanage fcontext -a -e /var/lib/containers/storage "${GRAPHROOT}"
    fi
    sudo restorecon -R -v "${GRAPHROOT}"

    # Disable copy-on-write for container layers where supported.
    sudo chattr +C "${GRAPHROOT}" 2>/dev/null || true

    sudo chown -R "${USER}:${USER}" "${BUILD_TMP}" "${BUILD_OUTPUT}"

    sudo env CONTAINERS_STORAGE_CONF="${STORAGE_CONF}" podman info >/dev/null
    echo "Rootful build storage initialized at ${GRAPHROOT}"
    df -h "${BUILD_ROOT}" /var

# Clean build outputs and temporary files, keeping the image cache
[group('Utility')]
clean-build:
    #!/usr/bin/env bash
    set -euo pipefail

    BUILD_ROOT="{{ BUILD_ROOT }}"
    if [[ -z "${BUILD_ROOT}" || "${BUILD_ROOT}" == "/" ]]; then
        echo "Error: refusing to clean BUILD_ROOT=${BUILD_ROOT}" >&2
        exit 1
    fi

    sudo rm -rf "{{ BUILD_OUTPUT_DIR }}" "{{ BUILD_TMP_DIR }}"
    sudo mkdir -p "{{ BUILD_OUTPUT_DIR }}" "{{ BUILD_TMP_DIR }}"
    sudo chown -R "${USER}:${USER}" "{{ BUILD_OUTPUT_DIR }}" "{{ BUILD_TMP_DIR }}"

# Remove cached images from the BUILD_ROOT Podman storage
[confirm("Remove all images and containers from the BUILD_ROOT Podman storage?")]
[group('Utility')]
clean-build-storage:
    ./scripts/podman-rootful.sh system prune -a -f

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# This Justfile recipe builds a container image using Podman.
#
# Arguments:
#   $flavor - The name of the flavor (e.g., bazzite-gnome).
#
# The script constructs the version string using the tag and the current date.
# If the git working directory is clean, it also includes the short SHA of the current HEAD.
#
# just build $flavor
#
# Example usage:
#   just build aurora
#
# This will build an image 'aurora' with the default tag.
#

# Build Image
build flavor:
    #!/usr/bin/env bash
    set -euo pipefail

    export IMAGE_NAME="{{ flavor }}"
    export FLAVOR_DIR="images/${IMAGE_NAME}"

    if [[ ! -d "${FLAVOR_DIR}" ]]; then
      echo "Error: The directory ${FLAVOR_DIR} does not exist."
      exit 1
    fi

    podman build \
      -f "$FLAVOR_DIR/Containerfile" \
      --build-arg IMAGE_NAME="$IMAGE_NAME" \
      --build-arg IMAGE_REGISTRY="$IMAGE_REGISTRY" \
      --build-arg IMAGE_DESC="Bazzite-{{ flavor }}" \
      --build-arg IMAGE_KEYWORDS="bazzite" \
      --tag $IMAGE_REGISTRY/$IMAGE_NAME:$default_tag \
      .

# Build Image into the BUILD_ROOT rootful storage
[group('Build Image')]
build-rootful flavor:
    #!/usr/bin/env bash
    set -euo pipefail

    export IMAGE_NAME="{{ flavor }}"
    export FLAVOR_DIR="images/${IMAGE_NAME}"

    if [[ ! -d "${FLAVOR_DIR}" ]]; then
      echo "Error: The directory ${FLAVOR_DIR} does not exist."
      exit 1
    fi

    ./scripts/podman-rootful.sh build \
      -f "$FLAVOR_DIR/Containerfile" \
      --security-opt label=disable \
      --build-arg IMAGE_NAME="$IMAGE_NAME" \
      --build-arg IMAGE_REGISTRY="$IMAGE_REGISTRY" \
      --build-arg IMAGE_DESC="Bazzite-{{ flavor }}" \
      --build-arg IMAGE_KEYWORDS="bazzite" \
      --tag "$IMAGE_REGISTRY/$IMAGE_NAME:$default_tag" \
      .

# Command: _rootful_load_image
# Description: Ensure an image is present in the BUILD_ROOT rootful storage.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the image is already in the BUILD_ROOT rootful storage.
# 2. If the image exists in user podman storage, copy it into BUILD_ROOT.
# 3. Otherwise pull it from the registry into BUILD_ROOT.

_rootful_load_image $target_image $tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, using the rootful build storage."
        exit 0
    fi

    if ./scripts/podman-rootful.sh image exists "${target_image}:${tag}" >/dev/null 2>&1; then
        echo "Image already present in rootful build storage: ${target_image}:${tag}"
        exit 0
    fi

    if podman image exists "${target_image}:${tag}" >/dev/null 2>&1; then
        echo "Copying ${target_image}:${tag} from user storage to build storage..."
        podman save "${target_image}:${tag}" | ./scripts/podman-rootful.sh load
        exit 0
    fi

    echo "Pulling ${target_image}:${tag} into build storage..."
    ./scripts/podman-rootful.sh pull "${target_image}:${tag}"

# Converts a container image to a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (default: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_build-bib $flavor $target_image $tag $type $config: (build-rootful flavor)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "{{ BUILD_TMP_DIR }}" -d -t _build-bib.XXXXXXXXXX)

    just _rootful_load_image "${target_image}" "${tag}"

    ./scripts/podman-rootful.sh run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v "$(pwd)/{{ config }}":/config.toml:ro \
      -v "${BUILDTMP}":/output \
      -v "{{ PODMAN_GRAPHROOT }}":/var/lib/containers/storage \
      "{{ bib_image }}" \
      ${args} \
      "{{ target_image }}:{{ tag }}"

    mkdir -p "{{ BUILD_OUTPUT_DIR }}"

    # Rename the output file using the flavor name before moving.
    case "$type" in
        qcow2 | raw)
            # The file is located in the $type subdirectory of the temporary build directory
            SOURCE_FILE="$BUILDTMP/$type/disk.$type"
            DEST_FILE="{{ BUILD_OUTPUT_DIR }}/{{ flavor }}.$type"

            if [ -f "$SOURCE_FILE" ]; then
                echo "Renaming $SOURCE_FILE to $DEST_FILE"
                sudo mv -f "$SOURCE_FILE" "$DEST_FILE"
                sudo chown $USER:$USER "$DEST_FILE"
            else
                echo "Error: Output file not found at expected location: $SOURCE_FILE"
                exit 1
            fi
            ;;
        iso)
            # ISO is located under 'bootiso'
            SOURCE_FILE="$BUILDTMP/bootiso/install.iso"
            DEST_FILE="{{ BUILD_OUTPUT_DIR }}/{{ flavor }}.iso"

            if [ -f "$SOURCE_FILE" ]; then
                echo "Renaming $SOURCE_FILE to $DEST_FILE"
                sudo mv -f "$SOURCE_FILE" "$DEST_FILE"
                sudo chown $USER:$USER "$DEST_FILE"
            else
                echo "Error: Output file not found at expected location: $SOURCE_FILE"
                exit 1
            fi
            ;;
        *)
            # Fallback for unexpected types
            echo "Moving $BUILDTMP contents to {{ BUILD_OUTPUT_DIR }}/"
            sudo mv -f $BUILDTMP/* "{{ BUILD_OUTPUT_DIR }}/"
            ;;
    esac

    # Clean up the temp directory
    sudo rm -rf $BUILDTMP

# Build the installer payload used by Titanoboa.
# Parameters:
#   flavor: The flavor being installed (ex. bazzite-gnome-nvidia)
#   target_image: The container image to embed for installation
#   tag: The tag of the image to embed
#
# Example: just _build-installer-payload bazzite-gnome-nvidia ghcr.io/benleppke/bazzite-gnome-nvidia latest
_build-installer-payload $flavor $target_image $tag:
    #!/usr/bin/env bash
    set -euo pipefail

    payload_base="{{ flavor }}"
    case "${payload_base}" in
        *-deck-* | *-nvidia*) payload_base="bazzite-gnome" ;;
    esac

    just _rootful_load_image "${IMAGE_REGISTRY}/${payload_base}" "{{ tag }}"
    just _rootful_load_image "{{ target_image }}" "{{ tag }}"

    TARGET_ARCHIVE="{{ BUILD_TMP_DIR }}/target-{{ flavor }}.oci"
    trap 'rm -f "${TARGET_ARCHIVE}"' EXIT

    ./scripts/podman-rootful.sh save \
      --format oci-archive \
      -o "${TARGET_ARCHIVE}" \
      "{{ target_image }}:{{ tag }}"

    TARGET_ID=$(./scripts/podman-rootful.sh image inspect --format=json "{{ target_image }}:{{ tag }}" | jq -r '.[0].Id')

    ./scripts/podman-rootful.sh build \
      --cap-add sys_admin \
      --security-opt label=disable \
      --volume "${TARGET_ARCHIVE}":/target-image.oci:ro \
      --build-arg BASE_IMAGE="${IMAGE_REGISTRY}/${payload_base}:{{ tag }}" \
      --build-arg INSTALL_IMAGE_PAYLOAD="{{ target_image }}:{{ tag }}" \
      --build-arg TARGET_IMAGE_ID="${TARGET_ID}" \
      --build-arg FLATPAK_DIR_SHORTNAME=gnome_flatpaks \
      -t "localhost/payload-{{ flavor }}:{{ tag }}" \
      installer/

# Package an existing installer payload into a live ISO with Titanoboa.
# Parameters:
#   flavor: The flavor being packaged (ex. bazzite-gnome-nvidia)
#   tag: The tag of the payload image
#
# Example: just _package-live-iso bazzite-gnome-nvidia latest
_package-live-iso $flavor $tag:
    #!/usr/bin/env bash
    set -euo pipefail

    if ! ./scripts/podman-rootful.sh image exists "localhost/payload-{{ flavor }}:{{ tag }}"; then
        echo "Error: payload image localhost/payload-{{ flavor }}:{{ tag }} not found." >&2
        echo "Run 'just build-live-iso {{ flavor }}' or 'just build-installer-payload {{ flavor }}' first." >&2
        exit 1
    fi

    BUILDTMP=$(mktemp -p "{{ BUILD_TMP_DIR }}" -d -t _build-live.XXXXXXXXXX)
    trap 'sudo rm -rf "${BUILDTMP}"' EXIT

    ./scripts/podman-rootful.sh run \
      --rm \
      --cap-add sys_admin \
      --security-opt label=disable \
      -v "${BUILDTMP}":/output \
      -v "$(pwd)/scripts/titanoboa/build_iso.sh":/src/build_iso.sh:ro \
      --mount type=image,source="localhost/payload-{{ flavor }}:{{ tag }}",dst=/rootfs \
      "{{ titanoboa_runtime_image }}" \
      /src/build_iso.sh

    iso_file=$(find "${BUILDTMP}" -maxdepth 1 -name '*.iso' -print -quit)
    if [[ -z "${iso_file}" ]]; then
        echo "Error: Titanoboa did not produce an ISO in ${BUILDTMP}" >&2
        exit 1
    fi

    mkdir -p "{{ BUILD_OUTPUT_DIR }}"
    sudo mv -f "${iso_file}" "{{ BUILD_OUTPUT_DIR }}/{{ flavor }}-live.iso"
    sudo chown "$USER:$USER" "{{ BUILD_OUTPUT_DIR }}/{{ flavor }}-live.iso"
    (cd "{{ BUILD_OUTPUT_DIR }}" && sha256sum "{{ flavor }}-live.iso" > "{{ flavor }}-live.iso-CHECKSUM")
    echo "Live ISO: {{ BUILD_OUTPUT_DIR }}/{{ flavor }}-live.iso"

# Build the payload and then package it into a live ISO.
# Parameters:
#   flavor: The flavor being installed (ex. bazzite-gnome-nvidia)
#   target_image: The container image to embed for installation
#   tag: The tag of the image to embed
#
# Example: just _build-live-iso bazzite-gnome-nvidia ghcr.io/benleppke/bazzite-gnome-nvidia latest
_build-live-iso $flavor $target_image $tag: (_build-installer-payload flavor target_image tag)
    @just _package-live-iso "{{ flavor }}" "{{ tag }}"

# Podman builds the image from the Containerfile and creates a bootable image
_rebuild-bib $flavor $target_image $tag $type $config: (build-rootful flavor) && (_build-bib flavor target_image tag type config)

# Build a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
build-qcow2 $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: && (_build-bib flavor target_image tag "qcow2" ("images/" + flavor + "/disk.toml"))

# Build a RAW virtual machine image
[group('Build Virtal Machine Image')]
build-raw $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: && (_build-bib flavor target_image tag "raw" ("images/" + flavor + "/disk.toml"))

# Build an ISO virtual machine image
[group('Build Virtal Machine Image')]
build-iso $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: && (_build-bib flavor target_image tag "iso" ("images/" + flavor + "/iso.toml"))

# Build a live ISO with Titanoboa from published images
[group('Build Live ISO')]
build-live-iso $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: && (_build-live-iso flavor target_image tag)

# Build a live ISO from a locally built container image
[group('Build Live ISO')]
build-live-iso-from-source $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: (build-rootful flavor) && (_build-live-iso flavor target_image tag)

# Build the Titanoboa installer payload only
[group('Build Live ISO')]
build-installer-payload $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: && (_build-installer-payload flavor target_image tag)

# Package an existing installer payload into a live ISO
[group('Build Live ISO')]
package-live-iso $flavor $tag=default_tag: && (_package-live-iso flavor tag)

# Extract the netboot kernel, initrd, and squashfs from a built live ISO
[group('Build Live ISO')]
build-netboot-assets $flavor:
    #!/usr/bin/env bash
    set -euo pipefail

    iso="{{ BUILD_OUTPUT_DIR }}/{{ flavor }}-live.iso"
    out="{{ BUILD_OUTPUT_DIR }}/netboot/{{ flavor }}"

    if [[ ! -f "${iso}" ]]; then
        echo "Error: ${iso} not found. Run 'just build-live-iso {{ flavor }}' first." >&2
        exit 1
    fi

    mkdir -p "${out}"
    mnt="$(mktemp -d -p "{{ BUILD_TMP_DIR }}")"
    trap 'sudo umount "${mnt}" 2>/dev/null || true; rmdir "${mnt}" 2>/dev/null || true' EXIT

    sudo mount -o loop,ro "${iso}" "${mnt}"
    sudo cp "${mnt}/images/pxeboot/vmlinuz" "${out}/vmlinuz"
    sudo cp "${mnt}/images/pxeboot/initrd.img" "${out}/initrd.img"
    sudo cp "${mnt}/LiveOS/squashfs.img" "${out}/squashfs.img"
    sudo umount "${mnt}"
    sudo chown "$USER:$USER" "${out}"/*

    payload="localhost/payload-{{ flavor }}:{{ default_tag }}"
    if ./scripts/podman-rootful.sh image exists "${payload}"; then
        if ! ./scripts/podman-rootful.sh run --rm \
            --security-opt label=disable \
            --entrypoint /usr/bin/lsinitrd \
            -v "${out}/initrd.img:/tmp/initrd.img:ro" \
            "${payload}" /tmp/initrd.img | grep -q 'parse-livenet'; then
            echo "Error: initrd is missing the livenet module." >&2
            exit 1
        fi
    fi

    sha256sum "${out}/vmlinuz" "${out}/initrd.img" "${out}/squashfs.img"
    echo "Netboot assets: ${out}"

# Rebuild a live ISO with Titanoboa
[group('Build Live ISO')]
rebuild-live-iso flavor:
    @just _build-live-iso "{{ flavor }}" "{{ IMAGE_REGISTRY }}/{{ flavor }}" "{{ default_tag }}"

# Rebuild a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
rebuild-qcow2 flavor:
    @just _rebuild-bib "{{ flavor }}" "{{ IMAGE_REGISTRY }}/{{ flavor }}" "{{ default_tag }}" "qcow2" "images/{{ flavor }}/disk.toml"

# Rebuild a RAW virtual machine image
[group('Build Virtal Machine Image')]
rebuild-raw flavor:
    @just _rebuild-bib "{{ flavor }}" "{{ IMAGE_REGISTRY }}/{{ flavor }}" "{{ default_tag }}" "raw" "images/{{ flavor }}/disk.toml"

# Rebuild an ISO virtual machine image
[group('Build Virtal Machine')]
rebuild-iso flavor:
    @just _rebuild-bib "{{ flavor }}" "{{ IMAGE_REGISTRY }}/{{ flavor }}" "{{ default_tag }}" "iso" "images/{{ flavor }}/iso.toml"

# Run a virtual machine with the specified image type and configuration
_run-vm $flavor $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    # Determine the image file based on the flavor and type
    if [[ $type == live-iso ]]; then
        image_file="{{ BUILD_OUTPUT_DIR }}/{{ flavor }}-live.iso"
        mount_type="iso"
    elif [[ $type == iso ]]; then
        image_file="{{ BUILD_OUTPUT_DIR }}/{{ flavor }}.iso"
        mount_type="iso"
    else
        image_file="{{ BUILD_OUTPUT_DIR }}/{{ flavor }}.${type}"
        mount_type="$type"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        if [[ $type == live-iso ]]; then
            just build-live-iso "{{ flavor }}" "$target_image" "$tag"
        else
            # Use the flavor in the build command
            just "build-${type}" "{{ flavor }}" "$target_image" "$tag"
        fi
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--security-opt label=disable)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${image_file}":"/boot.${mount_type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    ./scripts/podman-rootful.sh run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtal Machine')]
run-vm-qcow2 $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: && (_run-vm flavor target_image tag "qcow2" ("images/" + flavor + "/disk.toml"))

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: && (_run-vm flavor target_image tag "raw" ("images/" + flavor + "/disk.toml"))

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: && (_run-vm flavor target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine from a live ISO
[group('Run Virtal Machine')]
run-vm-live-iso $flavor $target_image=(IMAGE_REGISTRY + "/" + flavor) $tag=default_tag: && (_run-vm flavor target_image tag "live-iso" ("images/" + flavor + "/iso.toml"))

# Run a virtual machine using systemd-vmspawn
[group('Run Virtal Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i "{{ BUILD_OUTPUT_DIR }}"/*.{{ type }}

# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
