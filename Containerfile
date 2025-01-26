###
### Containerfile.nvidia - used to build ONLY NVIDIA kmods
###

ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-40}"
ARG BUILDER_IMAGE="${BUILDER_IMAGE:-quay.io/fedora/fedora}"
ARG BUILDER_BASE="${BUILDER_IMAGE}:${FEDORA_MAJOR_VERSION}"
FROM ${BUILDER_BASE} AS builder

ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-40}"
ARG NVIDIA_VERSION="${NVIDIA_VERSION:-stable}"
ARG KERNEL_NAME="${KERNEL_NAME:-kernel-cachyos}"
ARG KERNEL_MODULE_TYPE="${KERNEL_MODULE_TYPE:-kernel-open}"

COPY build-kmod-nvidia.sh /tmp/
COPY certs /tmp/certs
COPY etc etc

# files for nvidia
RUN --mount=type=cache,dst=/var/cache/dnf \
    /tmp/build-kmod-nvidia.sh "${KERNEL_MODULE_TYPE}" "${NVIDIA_VERSION}" "${KERNEL_NAME}" && \
    for RPM in $(find /var/cache/akmods/ -type f -name \*.rpm); do \
        cp "${RPM}" /var/cache/rpms/kmods/; \
    done && \
    find /var/cache/rpms

FROM scratch

COPY --from=builder /var/cache/rpms /rpms
