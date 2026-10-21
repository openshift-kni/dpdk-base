FROM registry.access.redhat.com/ubi9/ubi-micro:latest@sha256:5be877a2a280ae36eb9ab80ca4efb28bbf77c57abbba38137cdc37a03b8465e6 AS micro

# Install into Micro's filesystem using tools from the build stage. Konflux
# mounts its prefetched RPM repositories in /etc/yum.repos.d in this stage.
FROM registry.access.redhat.com/ubi9/ubi:latest@sha256:16e9e43d99e181463513cc84a514859b1abb9460f1c4d9e208da4b4e51cd5cc3 AS rootfs

COPY --from=micro / /mnt/rootfs/

# Keep the S2I development tools (including yum) for existing consumers.
# rpm and shadow-utils were previously supplied by UBI Minimal.
RUN INSTALL_PKGS="bsdtar \
  findutils \
  groff-base \
  glibc-locale-source \
  glibc-minimal-langpack \
  gettext \
  rsync \
  scl-utils \
  tar \
  unzip \
  xz \
  yum \
  dpdk \
  dpdk-devel \
  dpdk-tools \
  make \
  rdma-core \
  libibverbs \
  git \
  gcc \
  which \
  expect \
  rpm \
  shadow-utils" && \
  rpm --root /mnt/rootfs --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release && \
  dnf --installroot=/mnt/rootfs --releasever=9 \
    --setopt=reposdir=/etc/yum.repos.d \
    --setopt=tsflags=nodocs -y install $INSTALL_PKGS && \
  rpm --root /mnt/rootfs -V $INSTALL_PKGS && \
  dnf --installroot=/mnt/rootfs --releasever=9 \
    --setopt=reposdir=/etc/yum.repos.d -y clean all

FROM micro AS final

COPY --from=rootfs /mnt/rootfs/ /

LABEL com.redhat.component="dpdk-base-container" \
    name="openshift5/dpdk-base-rhel9" \
    cpe="cpe:/a:redhat:openshift:5.1::el9" \
    version="${CI_CONTAINER_VERSION}" \
    summary="dpdk-base" \
    io.openshift.expose-services="" \
    io.openshift.tags="< tags >" \
    io.k8s.display-name="dpdk-base" \
    io.k8s.description="Base image for dpdk" \
    io.openshift.s2i.scripts-url=image:///usr/libexec/s2i \
    io.s2i.scripts-url=image:///usr/libexec/s2i \
    description="dpdk-base"

ENV \
    APP_ROOT=/opt/app-root \
    # The $HOME is not set by default, but some applications needs this variable
    HOME=/opt/app-root/src \
    PATH=$PATH:/opt/app-root/src/bin:/opt/app-root/bin \
    PLATFORM="el9"

ENV BUILDER_VERSION 0.1
ENV DPDK_VER 23.11-1
ENV DPDK_DIR /usr/share/dpdk
ENV RTE_TARGET=x86_64-default-linux-gcc
ENV RTE_EXEC_ENV=linux
ENV RTE_SDK=${DPDK_DIR}

RUN mkdir -p ${HOME}/.pki/nssdb && \
  chown -R 1001:0 ${HOME}/.pki

# in dpdk 20.11 the testpmd bin changed to dpdk-testpmd
# for backport support we add a symlink
RUN ln -s /usr/bin/dpdk-testpmd /usr/bin/testpmd

# Directory with the sources is set as the working directory so all STI scripts
# can execute relative to this path.
WORKDIR ${HOME}

# Reset permissions of modified directories and add default user
RUN useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin \
      -c "Default Application User" default && \
  chown -R 1001:0 ${APP_ROOT}

COPY ./s2i/bin/ /usr/libexec/s2i

RUN setcap cap_ipc_lock=+ep /usr/libexec/s2i/run \
    && setcap cap_sys_resource=+ep /usr/libexec/s2i/run

# Allows non-root users to use dpdk-testpmd
RUN setcap cap_sys_resource,cap_ipc_lock,cap_net_raw+ep /usr/bin/dpdk-testpmd
RUN setcap cap_sys_resource,cap_ipc_lock,cap_net_raw+ep /usr/bin/dpdk-test-bbdev

# Add supplementary group 801 to user 1001 in order to use the VFIO device in a non-privileged pod.
RUN groupadd -g 801 hugetlbfs
RUN usermod -aG hugetlbfs default

# This is needed for the s2i to work
# in the pod yaml we still use the runAsUser:0 we w/a the ulimit issue
USER default

CMD ["/usr/libexec/s2i/usage"]
