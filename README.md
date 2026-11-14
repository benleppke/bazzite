# bazzite

Personal customized [Bazzite](https://bazzite.gg/) bootc images, derived from
the upstream `ghcr.io/ublue-os/bazzite-*:stable` images with my package,
desktop, and theming changes.

This is not a general-purpose distribution. It is built and signed for my own
machines.

## Published images

Images are built by `.github/workflows/build.yml` on pushes to `main` and on
the daily schedule, then pushed to GitHub Container Registry.

| Flavor | Image |
| --- | --- |
| GNOME | `ghcr.io/benleppke/bazzite-gnome:latest` |
| GNOME + NVIDIA | `ghcr.io/benleppke/bazzite-gnome-nvidia:latest` |
| Deck GNOME | `ghcr.io/benleppke/bazzite-deck-gnome:latest` |

Tags include `latest`, `latest.YYYYMMDD`, and branch tags. Images are cosigned
with the key in `cosign.pub`.

Switch an existing system with:

```bash
sudo bootc switch ghcr.io/benleppke/bazzite-gnome:latest
```

## Local builds

The `Justfile` is the main local build entry point. Run `just` to list all
recipes.

```bash
just build <flavor>          # rootless container build
just build-rootful <flavor>  # container build into BUILD_ROOT storage
just build-qcow2 <flavor>    # QCOW2 VM image
just build-raw <flavor>      # raw VM image
just build-iso <flavor>      # legacy bootc-image-builder Anaconda ISO
just build-live-iso <flavor> # Titanoboa live ISO
just run-vm-live-iso <flavor>
```

The Justfile loads `.env`. Copy `.env.example` and set `BUILD_ROOT` to a disk
with room for container storage and images, then initialize it once:

```bash
just setup-build-dir
```

`just build` uses rootless Podman on the primary disk. Use `build-rootful` and
the ISO recipes to keep everything under `BUILD_ROOT`.

## ISO builds

### Live ISO

`.github/workflows/build-live.yml` builds a bootable live ISO using
[Titanoboa](https://github.com/ublue-os/titanoboa). It boots a live GNOME
desktop with the Anaconda live installer.

The live ISO is not built directly from the desktop image. The workflow first
builds an installer payload from the vendored [`installer/`](installer/)
directory using the non-Deck/non-NVIDIA desktop image as the live base,
embeds the selected flavor image for offline installation, and then packages
it with Titanoboa.

- `workflow_dispatch` input `flavor`: `all`, `bazzite-gnome`,
  `bazzite-gnome-nvidia`, or `bazzite-deck-gnome`. The workflow also runs
  weekly on Sunday at 02:00 UTC and builds all three flavors.
- Output per flavor: `bazzite-<flavor>-live-amd64.iso`, a `.sha256` checksum,
  a cosign `.sig`, extracted netboot assets, and a `manifest.json`.
- Runner requirements: self-hosted runner with rootful Podman, passwordless
  `sudo`, rclone, access to Backblaze B2, and at least 80G free in container
  storage plus 25G in the workspace.

Build locally with:

```bash
just build-live-iso bazzite-gnome
just run-vm-live-iso bazzite-gnome
```

To build the container image locally into the same storage first:

```bash
just build-rootful bazzite-gnome
just build-live-iso-from-source bazzite-gnome
```

To build only the installer payload, or repackage an existing payload without
rebuilding it:

```bash
just build-installer-payload bazzite-gnome
just package-live-iso bazzite-gnome
```

To extract the netboot kernel, initrd, and squashfs from a built ISO:

```bash
just build-netboot-assets bazzite-gnome
```

Local ISO packaging uses the vendored
[`scripts/titanoboa/build_iso.sh`](scripts/titanoboa/build_iso.sh) in a Fedora
container, so it does not depend on the private Titanoboa container image. The
installer files are vendored from `ublue-os/bazzite`; see
[`installer/README.md`](installer/README.md) for the pinned upstream commit and
local changes.

### Downloads

Scheduled builds publish to Backblaze B2 behind `isos.benleppke.com`. Dated
snapshots are kept for roughly four weeks; `latest` always points at the most
recent successful build.

Stable links:

```text
https://isos.benleppke.com/bazzite/latest/bazzite-gnome-live-amd64.iso
https://isos.benleppke.com/bazzite/latest/bazzite-gnome-nvidia-live-amd64.iso
https://isos.benleppke.com/bazzite/latest/bazzite-deck-gnome-live-amd64.iso
```

Each ISO has a `.sha256` and `.sig` next to it. The machine-readable index is:

```text
https://isos.benleppke.com/bazzite/latest/index.json
```

Dated builds live under `bazzite/live/<YYYY-MM-DD>/`, including extracted
netboot assets:

```text
bazzite/live/<date>/netboot/<flavor>/vmlinuz
bazzite/live/<date>/netboot/<flavor>/initrd.img
bazzite/live/<date>/netboot/<flavor>/squashfs.img
```

The live initramfs is built with the `livenet` dracut module, so the kernel,
initrd, and squashfs can boot over `root=live:nfs://` or `root=live:http://`.

Publishing uses the repository variable `B2_BUCKET_NAME` (default
`benleppke-bazzite-isos`) and the secrets `B2_APPLICATION_KEY_ID` and
`B2_APPLICATION_KEY`.

### Legacy Anaconda ISO

`.github/workflows/build-disk.yml` builds the previous install-only Anaconda
ISO with bootc-image-builder. It does **not** include a live desktop. Keep
using that workflow for the legacy behavior.

### Build storage

Live ISO builds can use 90–120G across container storage, temporary files, and
output. Point `BUILD_ROOT` at a large disk to keep this off the primary disk:

```bash
BUILD_ROOT=/run/media/ben/ssd3/Build
```

`just setup-build-dir` creates the rootful Podman storage config, labels it for
SELinux, and creates the temp and output directories. Clean up without removing
the cached images:

```bash
just clean-build
```

Remove the cached images too:

```bash
just clean-build-storage
```
