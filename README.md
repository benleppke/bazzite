# image-template

# Purpose

This repository is meant to be a template for building your own custom [bootc](https://github.com/bootc-dev/bootc) image. This template is the recommended way to make customizations to any image published by the Universal Blue Project:
- Products: [Aurora](https://getaurora.dev/), [Bazzite](https://bazzite.gg/), [Bluefin](https://projectbluefin.io/), [uCore](https://projectucore.io/)
- Base images: [main](https://github.com/ublue-os/main/) - the product images build on these and may be a better starting point depending on what you want. 

or any other base image if you want to start from scratch:

- Fedora: `quay.io/fedora/fedora-bootc:41`
- CentOS Stream 10: `quay.io/centos-bootc/centos-bootc:stream10`

This template includes a Containerfile and a Github workflow for building the container image, signing, and proper metadata to be listed on [artifacthub](https://artifacthub.io/). As soon as the workflow is enabled in your repository, it will build the container image and push it to the Github Container Registry.

# Prerequisites

Working knowledge in the following topics:

- Containers
  - https://www.youtube.com/watch?v=SnSH8Ht3MIc
  - https://www.mankier.com/5/Containerfile
- bootc
  - https://bootc-dev.github.io/bootc/
- Fedora Silverblue (and other Fedora Atomic variants)
  - https://docs.fedoraproject.org/en-US/fedora-silverblue/
- Github Workflows
  - https://docs.github.com/en/actions/using-workflows

# Video Tutorial

TesterTech has made a tutorial video, check it out: 

[![Video Tutorial](https://img.youtube.com/vi/IxBl11Zmq5w/0.jpg)](https://www.youtube.com/watch?v=IxBl11Zmq5wE)

# How to Use

## Template

Select `Use this Template` and create a new repository from it. To enable the workflows, you may need to go the `Actions` tab of the new repository and click to enable workflows.

## Containerfile

This file defines the operations used to customize the selected image. It contains examples of possible modifications, including how to:
- change the upstream from which the custom image is derived
- add additional RPM packages
- add binaries as a layer from other images

## Building disk images

This template provides an out of the box workflow for creating ISO and other disk images for your custom OCI image which can be used to directly install onto your machines.

This template provides a way to upload the disk images that is generated from the workflow to a S3 bucket or it will be available as an artifact from the job. To upload to S3 we use a tool called [rclone](https://rclone.org/) which is able to use [many S3 providers](https://rclone.org/s3/). For more details on how to configure this see the details [below](#build-isoyml).

## Workflows

### build.yml

This workflow creates your custom OCI image and publishes it to the Github Container Registry (GHCR). By default, the image name will match the Github repository name.

### build-disk.yml

This workflow creates a disk images from your OCI image by utilizing the [bootc-image-builder](https://osbuild.org/docs/bootc/). In order to use this workflow you must complete the following steps:

- Modify `disk_config/iso.toml` to point to your custom container image before generating an ISO image.
- If you changed your image name from the default in `build.yml` then in the `build-disk.yml` file edit the `IMAGE_REGISTRY`, `IMAGE_NAME` and `DEFAULT_TAG` environment variables with the correct values. If you did not make changes, skip this step.
- Finally, if you want to upload your disk images to S3 then you will need to add your S3 configuration to the repository's Action secrets. This can be found by going to your repository settings, under `Secrets and Variables` -> `Actions`. You will need to add the following
  - `S3_PROVIDER` - Must match one of the values from the [supported list](https://rclone.org/s3/)
  - `S3_BUCKET_NAME` - Your unique bucket name
  - `S3_ACCESS_KEY_ID` - It is recommended that you make a separate key just for this workflow
  - `S3_SECRET_ACCESS_KEY` - See above.
  - `S3_REGION` - The region your bucket lives in. If you do not know then set this value to `auto`.
  - `S3_ENDPOINT` - This value will be specific to the bucket as well.

Once the workflow is done, you'll find the disk images either in your S3 bucket or as part of the summary under `Artifacts` after the workflow is completed.

### build-live.yml

This workflow builds a bootable **live ISO** using [Titanoboa](https://github.com/ublue-os/titanoboa). Unlike `build-disk.yml`, the result boots into a live GNOME desktop with the Anaconda live installer.

The live ISO is not built directly from the desktop image. The workflow first builds an installer payload from the vendored [`installer/`](installer/) directory using the non-Deck/non-NVIDIA desktop image as the live base, embeds the selected flavor image for offline installation, and then asks Titanoboa to package it.

- `workflow_dispatch` input `flavor`: `all`, `bazzite-gnome`, `bazzite-gnome-nvidia`, or `bazzite-deck-gnome`.
- Output: `bazzite-<flavor>-live-latest-amd64.iso`, checksum, cosign signature, and build provenance attestation.
- Runner requirements: self-hosted runner with rootful Podman, passwordless `sudo`, and at least 80G free in container storage.

Build it locally with:

```bash
just build-live-iso bazzite-gnome
just run-vm-live-iso bazzite-gnome
```

To build only the installer payload:

```bash
just build-installer-payload bazzite-gnome-nvidia
```

The installer files under `installer/` are vendored from `ublue-os/bazzite`; see [`installer/README.md`](installer/README.md) for the pinned upstream commit and local changes.

#### Legacy Anaconda install ISO

`build-disk.yml` still builds the previous install-only Anaconda ISO with bootc-image-builder. It does **not** include a live desktop. Keep using that workflow if you want the previous behavior.

### Building locally on an external disk

Live ISO builds can use 90–120G across container storage, temporary files, and output. The Justfile supports a configurable `BUILD_ROOT` so this stays off the primary disk.

1. Copy `.env.example` to `.env` and set `BUILD_ROOT`, for example:

   ```bash
   BUILD_ROOT=/run/media/ben/ssd3/Build
   ```

2. Run the one-time storage setup:

   ```bash
   just setup-build-dir
   ```

   This creates the rootful Podman storage config, graphroot, temp directory, and output directory under `BUILD_ROOT`. It also labels the storage for SELinux and disables copy-on-write on btrfs.

3. Build and run:

   ```bash
   just build-live-iso bazzite-gnome
   just run-vm-live-iso bazzite-gnome
   ```

`build-live-iso` pulls the published images from GHCR. To build the container image locally into the same SSD storage instead:

```bash
just build-rootful bazzite-gnome
just build-live-iso-from-source bazzite-gnome
```

`just build` still uses rootless Podman and the primary disk. Use `build-rootful` for SSD-only local builds.

Clean up build outputs without removing the image cache:

```bash
just clean-build
```

Remove cached images from the `BUILD_ROOT` storage:

```bash
just clean-build-storage
```

If `BUILD_ROOT` is not set, it defaults to `build/` in the repository.

#### Container Signing

Container signing is important for end-user security and is enabled on all Universal Blue images. It is recommended you set this up, and by default the image builds *will fail* if you don't.

This provides users a method of verifying the image.

1. Install the [cosign CLI tool](https://edu.chainguard.dev/open-source/sigstore/cosign/how-to-install-cosign/#installing-cosign-with-the-cosign-binary)

2. Run inside your repo folder:

    ```bash
    cosign generate-key-pair
    ```

    
    - Do NOT put in a password when it asks you to, just press enter. The signing key will be used in GitHub Actions and will not work if it is encrypted.

> [!WARNING]
> Be careful to *never* accidentally commit `cosign.key` into your git repo.

3. Add the private key to GitHub

    - This can also be done manually. Go to your repository settings, under `Secrets and Variables` -> `Actions`
    ![image](https://user-images.githubusercontent.com/1264109/216735595-0ecf1b66-b9ee-439e-87d7-c8cc43c2110a.png)
    Add a new secret and name it `SIGNING_SECRET`, then paste the contents of `cosign.key` into the secret and save it. Make sure it's the .key file and not the .pub file. Once done, it should look like this:
    ![image](https://user-images.githubusercontent.com/1264109/216735690-2d19271f-cee2-45ac-a039-23e6a4c16b34.png)

    - (CLI instructions) If you have the `github-cli` installed, run:

    ```bash
    gh secret set SIGNING_SECRET < cosign.key
    ```

4. Commit the `cosign.pub` file to the root of your git repository.

# Community

- [**bootc discussion forums**](https://github.com/bootc-dev/bootc/discussions) - Nothing in this template is ublue specific, the upstream bootc project has a discussions forum where custom image builders can hang out and ask questions.

## Artifacthub

This template comes with the necessary tooling to index your image on [artifacthub.io](https://artifacthub.io), use the `artifacthub-repo.yml` file at the root to verify yourself as the publisher. This is important to you for a few reasons:

- The value of artifacthub is it's one place for people to index their custom images, and since we depend on each other to learn, it helps grow the community. 
- You get to see your pet project listed with the other cool projects in Cloud Native.
- Since the site puts your README front and center, it's a good way to learn how to write a good README, learn some marketing, finding your audience, etc. 

[Discussion thread](https://universal-blue.discourse.group/t/listing-your-custom-image-on-artifacthub/6446)


### Justfile Documentation

This `Justfile` contains various commands and configurations for building and managing container images and virtual machine images using Podman and other utilities.

#### Environment Variables

- `image_name`: The name of the image (default: "image-template").
- `default_tag`: The default tag for the image (default: "latest").
- `bib_image`: The Bootc Image Builder (BIB) image (default: "quay.io/centos-bootc/bootc-image-builder:latest").
- `titanoboa_image`: The Titanoboa container image used for live ISOs (default: "ghcr.io/ublue-os/titanoboa:latest").
- `BUILD_ROOT`: Rootful Podman storage, temp, and output directory (default: `build/` in the repo; loaded from `.env`).

#### Aliases

- `build-vm`: Alias for `build-qcow2`.
- `rebuild-vm`: Alias for `rebuild-qcow2`.
- `run-vm`: Alias for `run-vm-qcow2`.


#### Commands

###### `check`

Checks the syntax of all `.just` files and the `Justfile`.

###### `fix`

Fixes the syntax of all `.just` files and the `Justfile`.

###### `clean`

Cleans the repository by removing build artifacts.

###### `setup-build-dir`

Creates the `BUILD_ROOT` rootful Podman storage config, SELinux labels, temp directory, and output directory.

```bash
just setup-build-dir
```

###### `clean-build`

Removes build outputs and temporary files under `BUILD_ROOT` while keeping the image cache.

```bash
just clean-build
```

###### `clean-build-storage`

Removes all cached images and containers from the `BUILD_ROOT` Podman storage.

```bash
just clean-build-storage
```

##### Build Commands

###### `build`

Builds a container image using Podman.

```bash
just build $target_image $tag
```

Arguments:
- `$target_image`: The tag you want to apply to the image (default: `$image_name`).
- `$tag`: The tag for the image (default: `$default_tag`).

###### `build-rootful`

Builds a container image into the `BUILD_ROOT` rootful Podman storage.

```bash
just build-rootful $flavor
```

##### Building Virtual Machines and ISOs

###### `build-qcow2`

Builds a QCOW2 virtual machine image.

```bash
just build-qcow2 $target_image $tag
```

###### `build-raw`

Builds a RAW virtual machine image.

```bash
just build-raw $target_image $tag
```

###### `build-iso`

Builds an ISO virtual machine image.

```bash
just build-iso $target_image $tag
```

###### `build-live-iso`

Builds a live ISO using Titanoboa from the published images. This is the live desktop installer, not the legacy bootc-image-builder Anaconda ISO.

```bash
just build-live-iso $flavor
```

###### `build-live-iso-from-source`

Builds the container image into `BUILD_ROOT` with `build-rootful`, then builds the live ISO.

```bash
just build-live-iso-from-source $flavor
```

###### `build-installer-payload`

Builds only the Titanoboa installer payload image.

```bash
just build-installer-payload $flavor
```

###### `rebuild-qcow2`

Rebuilds a QCOW2 virtual machine image.

```bash
just rebuild-qcow2 $target_image $tag
```

###### `rebuild-raw`

Rebuilds a RAW virtual machine image.

```bash
just rebuild-raw $target_image $tag
```

###### `rebuild-iso`

Rebuilds an ISO virtual machine image.

```bash
just rebuild-iso $target_image $tag
```

###### `rebuild-live-iso`

Rebuilds a live ISO using Titanoboa.

```bash
just rebuild-live-iso $flavor
```

##### Run Virtual Machines

###### `run-vm-qcow2`

Runs a virtual machine from a QCOW2 image.

```bash
just run-vm-qcow2 $target_image $tag
```

###### `run-vm-raw`

Runs a virtual machine from a RAW image.

```bash
just run-vm-raw $target_image $tag
```

###### `run-vm-iso`

Runs a virtual machine from an ISO.

```bash
just run-vm-iso $target_image $tag
```

###### `run-vm-live-iso`

Runs a virtual machine from a Titanoboa live ISO.

```bash
just run-vm-live-iso $flavor
```

###### `spawn-vm`

Runs a virtual machine using systemd-vmspawn.

```bash
just spawn-vm rebuild="0" type="qcow2" ram="6G"
```

##### Lint and Format

###### `lint`

Runs shell check on all Bash scripts.

###### `format`

Runs shfmt on all Bash scripts.

## Community Examples

- [m2Giles' OS](https://github.com/m2giles/m2os)
- [bOS](https://github.com/bsherman/bos)
- [Homer](https://github.com/bketelsen/homer/)
- [Amy OS](https://github.com/astrovm/amyos)
- [VeneOS](https://github.com/Venefilyn/veneos)
