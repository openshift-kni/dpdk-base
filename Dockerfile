FROM registry.redhat.io/rhel8-6-els/rhel:8.6

LABEL com.redhat.component="dpdk-base-container" \
    name="openshift4/dpdk-base-rhel8" \
    cpe="cpe:/a:redhat:openshift:4.12::el8" \
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
    PLATFORM="el8"

ENV BUILDER_VERSION 0.1
ENV DPDK_VER 23.11-1
ENV DPDK_DIR /usr/share/dpdk
ENV RTE_TARGET=x86_64-default-linux-gcc
ENV RTE_EXEC_ENV=linux
ENV RTE_SDK=${DPDK_DIR}

RUN INSTALL_PKGS="bsdtar \
  findutils \
  groff-base \
  glibc-locale-source \
  glibc-langpack-en \
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
  expect" && \
  mkdir -p ${HOME}/.pki/nssdb && \
  chown -R 1001:0 ${HOME}/.pki && \
  dnf --setopt=tsflags=nodocs -y install $INSTALL_PKGS && \
  rpm -V $INSTALL_PKGS && \
  dnf -y clean all --enablerepo='*'

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

# This is needed for the s2i to work
# in the pod yaml we still use the runAsUser:0 we w/a the ulimit issue
USER 1001

CMD ["/usr/libexec/s2i/usage"]

