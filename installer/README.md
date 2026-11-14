# Live installer payload

This directory is vendored from [ublue-os/bazzite](https://github.com/ublue-os/bazzite)
at commit `ce9229d7b3b994b4570c5e40eec0659523b6bb27` (`installer/`).

It builds the payload image that [Titanoboa](https://github.com/ublue-os/titanoboa)
turns into a live ISO. The payload is **not** the image that gets installed: it
contains the live desktop, Anaconda, the live initramfs, and a copy of the
target container image that Anaconda installs from local storage.

## How it fits together

1. `.github/workflows/build-live.yml` (or `just build-live-iso`) builds this
   payload with:
   - `BASE_IMAGE` set to the non-Deck/non-NVIDIA desktop image
     (`bazzite-gnome`),
   - `INSTALL_IMAGE_PAYLOAD` set to the flavor being installed
     (`bazzite-gnome`, `bazzite-gnome-nvidia`, or `bazzite-deck-gnome`).
2. Titanoboa packages the payload into a bootable live ISO.
3. At install time, Anaconda writes the embedded target image to disk and
   rebases the installed system onto the target registry ref.

## Local changes from upstream

- The target image ref is written to `/etc/ublue-os/install-image` during the
  payload build. The installer hook reads it instead of globbing
  `podman images` for names starting with `bazzite`, so images hosted under a
  personal GHCR namespace work reliably.
- `titanoboa_hook_postrootfs.sh` no longer passes
  `--enforce-container-sigpolicy` to `bootc switch`. These images are signed
  with this repository's cosign key, which is not part of the upstream ublue
  signature policy. Add the key to the image policy before re-enabling
  enforcement.
- `build.sh` loads `/target-image.oci` when present. Local builds mount an OCI
  archive of the target image so from-source builds use the image in the build
  storage instead of pulling the published tag.
- `Containerfile` accepts `TARGET_IMAGE_ID` and passes it to the build
  environment only so Buildah invalidates the payload RUN cache when the
  target image changes. The archive itself is not part of the RUN cache key.
- The live-session hardware helper matches `*bazzite*` instead of `bazzite*`.
- The Swedish live MOTD and its locale branch are removed; the live MOTD is
  English-only. The upstream Swedish dialog strings in `on_gui_login.sh` are
  left in place but are unused with an English locale.
- `gnome_flatpaks/flatpaks` has the duplicate `protontricks` entry removed.

## Maintaining it

Upstream changes this directory as Bazzite's live ISO evolves. When syncing:

1. Fetch `installer/` from a newer `ublue-os/bazzite` commit.
2. Re-apply the local changes listed above.
3. Update the commit SHA in this file.
4. Build and boot-test at least `bazzite-gnome` before merging.

Only GNOME flavors are built here. The KDE files are kept so the vendored copy
stays close to upstream, but they are not used by the current workflows.
