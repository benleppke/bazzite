# Titanoboa build script

`build_iso.sh` is vendored from
[ublue-os/titanoboa](https://github.com/ublue-os/titanoboa) at commit
`5c457c3d0518bd17e754be0fd98a60d29d26abb4`.

The local Justfile runs this script inside `quay.io/fedora/fedora:latest`
instead of pulling `ghcr.io/ublue-os/titanoboa:latest`. The published
container image is not anonymously pullable, while the action the workflow
uses checks out the repository and runs this same script.

Keep this file in sync with the Titanoboa SHA pinned in
`.github/workflows/build-live.yml`.
