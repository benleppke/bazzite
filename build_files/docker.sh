#!/bin/bash

echo "Running docker script..."
set -ouex pipefail

dnf5 install -y \
  --enablerepo=docker-ce \
  containerd.io \
  docker-buildx-plugin \
  docker-ce \
  docker-ce-cli \
  docker-compose-plugin

cat > /usr/lib/sysusers.d/docker.sysusers <<EOF
g docker - "Docker Group"
EOF

systemctl enable docker.socket