# Bazzite

Customized [Bazzite](https://bazzite.gg/) bootc images, built on `ghcr.io/ublue-os/bazzite-*:stable` with additional packages providing tools and theming.

> [!CAUTION]
> These images are not intended for general purpose use. They are tuned to my own personal workflow and tastes which may change at any time without warning.

While these images are listed publicly primarily for my own convenience I do also provide this project as example you can reference if you want to [create your own image](https://github.com/ublue-os/image-template).

## Published images

Images are built daily and pushed to GHCR.

| Flavor | Image |
| --- | --- |
| GNOME | `ghcr.io/benleppke/bazzite-gnome:latest` |
| GNOME + NVIDIA | `ghcr.io/benleppke/bazzite-gnome-nvidia:latest` |
| Deck GNOME | `ghcr.io/benleppke/bazzite-deck-gnome:latest` |

Tags include `latest`, `latest.YYYYMMDD`, and branch tags.

Switch an existing system with:

```bash
sudo bootc switch ghcr.io/benleppke/bazzite-gnome:latest
```

## Local builds

Run `just` to list all recipes.

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
- Output per flavor: `bazzite-<flavor>-live-amd64.iso`, a `.sha256` checksum
  signed with cosign, extracted netboot assets, and a `manifest.json`.
- The `publish` job then regenerates `index.json`, the download page
  (`index.html`), the aggregate `SHA256SUMS`, and the netboot menu from what is
  in the bucket. `scripts/flavors.json` is the flavor list: display names for
  the page and menu, the payload base each flavor builds from, and the order
  both present them in. Adding a flavor means editing that file and the
  `workflow_dispatch` options.
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

Scheduled builds publish a download page at <https://isos.benleppke.com/>,
rendered from the release index by
[`scripts/iso_index.py`](scripts/iso_index.py). Dated snapshots are kept for
roughly four weeks; `latest` always points at the most recent successful build.

Stable links:

```text
https://isos.benleppke.com/bazzite/latest/bazzite-gnome-live-amd64.iso
https://isos.benleppke.com/bazzite/latest/bazzite-gnome-nvidia-live-amd64.iso
https://isos.benleppke.com/bazzite/latest/bazzite-deck-gnome-live-amd64.iso
```

Each ISO has a `.sha256`; the checksum is cosign-signed and published as
`.sha256.bundle`. `SHA256SUMS` covers every published ISO and is signed as a
single file, and the verification key ships beside the signatures:

```text
https://isos.benleppke.com/bazzite/latest/{SHA256SUMS,SHA256SUMS.bundle,cosign.pub}
```

With the ISOs in the current directory:

```bash
curl -LO https://isos.benleppke.com/bazzite/latest/SHA256SUMS
curl -LO https://isos.benleppke.com/bazzite/latest/SHA256SUMS.bundle
curl -LO https://isos.benleppke.com/bazzite/latest/cosign.pub
cosign verify-blob --key cosign.pub --bundle SHA256SUMS.bundle SHA256SUMS
sha256sum -c SHA256SUMS
```

The aggregate is composed only from hashes whose per-ISO signature already
verified against the committed [`cosign.pub`](cosign.pub), so it cannot vouch
for an artifact the release signature does not cover. The machine-readable
release index is:

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

Each release is also mirrored to stable paths that never expire, so a boot
loader config does not have to track the build date:

```text
bazzite/latest/netboot/<flavor>/{vmlinuz,initrd.img,squashfs.img,manifest.json}
```

netboot.xyz only needs to chain to one generated iPXE menu:

```text
https://isos.benleppke.com/bazzite/latest/menu.ipxe
```

The menu is rebuilt from `index.json` on every publish run: it lists the latest
release per flavor plus the older releases still inside the lifecycle window.
Note that `root=live:http(s)://` downloads the whole squashfs into the
initramfs (`/tmp`, i.e. RAM); targets using this need at least 16 GB of RAM.

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
