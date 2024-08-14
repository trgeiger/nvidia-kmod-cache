#!/bin/sh

set -oeux pipefail

RELEASE="$(rpm -E '%fedora.%_arch')"
KERNEL_MODULE_TYPE="${1:-kernel}"
KERNEL_NAME="kernel-cachyos"

cd /tmp

### Prep

# Install kernel repo
dnf install -y wget
wget https://github.com/trgeiger/cpm/releases/download/v1.0.3/cpm -O /usr/bin/cpm && chmod +x /usr/bin/cpm
cpm enable \
    bieszczaders/kernel-cachyos

# Install RPMFusion
RPMFUSION_MIRROR_RPMS="https://mirrors.rpmfusion.org"
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    fedora-repos-archive

# Install kernel
dnf install -y \
    kernel-cachyos \
    kernel-cachyos-devel-matched

# Install build reqs
dnf install -y \
    akmods

install -Dm644 /tmp/certs/quark-secure-boot.der   /etc/pki/akmods/certs/public_key.der
install -Dm644 /tmp/certs/private_key.priv /etc/pki/akmods/private/private_key.priv

# Fix important directory permissions
chmod 1777 /tmp /var/tmp

# Create directories for resulting artifacts
mkdir -p /var/cache/rpms/{kmods}

### BUILD nvidia

dnf install -y \
    akmod-nvidia

# Either successfully build and install the kernel modules, or fail early with debug output
rpm -qa |grep nvidia
KERNEL_VERSION="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
NVIDIA_AKMOD_VERSION="$(basename "$(rpm -q "akmod-nvidia" --queryformat '%{VERSION}-%{RELEASE}')" ".fc${RELEASE%%.*}")"

if [[ "${KERNEL_MODULE_TYPE}" == "kernel-open" ]]; then
    sh -c 'echo "%_with_kmod_nvidia_open 1" > /etc/rpm/macros.nvidia-kmod'
fi 

akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null || \
(cat /var/cache/akmods/nvidia/${NVIDIA_AKMOD_VERSION}-for-${KERNEL_VERSION}.failed.log && exit 1)

# View license information
modinfo -l /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

# create a directory for later copying of resulting nvidia specific artifacts
mkdir -p /var/cache/rpms/kmods/nvidia

cat <<EOF > /var/cache/rpms/kmods/nvidia-vars
KERNEL_VERSION=${KERNEL_VERSION}
KERNEL_MODULE_TYPE=${KERNEL_MODULE_TYPE}
RELEASE=${RELEASE}
NVIDIA_AKMOD_VERSION=${NVIDIA_AKMOD_VERSION}
EOF
