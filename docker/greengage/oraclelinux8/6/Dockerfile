# Differences from the vanilla Greenplum image
# ----
# Start from greengage 6.28.1 the dependence of patched xerces is removed.
# So we can use the standard xerces-c package
# See https://github.com/GreengageDB/greengage/commit/431a01f4394461092842718aa7c37a0a98e2bfaa
# and https://github.com/GreengageDB/greengage/commit/dff485b8f1e1e4ebe771de9a3ba93af42c7624d1
# The build step for patched xerces has been removed for greengage, unlike the vanilla greenplum.
# ----
# PXF requires Java 17
# See https://github.com/GreengageDB/pxf/commit/1a873abd57983bf658822cb9b02a11b011116812
# ----
# For compiling Greengage zstd static library (.a files) is needed.
# See https://github.com/GreengageDB/greengage/commit/7185bf85ea8f4abdfdeb08d5a53180ea2f389728
# On Ubuntu it's not needed as libzstd-dev contains .a files
# But on Oracle Linux we need to build and install zstd from sources, because
# the standard package libzstd-devel doesn't contain static library files.
# ----
ARG REPO_BUILD_TAG
ARG OL_VERSION="8"
ARG GOLANG_VERSION="1.25.11"
ARG LIBSIGAR_DOWNLOAD_URL="https://github.com/boundary/sigar"
ARG LIBSIGAR_COMMIT_HASH="e8961a6674cc4d292e61b353b5c36bfc345434cc"
ARG GPDB_REPO_URL="https://github.com/GreengageDB/greengage.git"
ARG GPDB_VERSION="6.31.0"
ARG DISKQUOTA_DOWNLOAD_URL="https://github.com/GreengageDB/diskquota/archive/refs/tags"
ARG DISKQUOTA_VERSION="2.4.1"
ARG PXF_DOWNLOAD_URL="https://github.com/GreengageDB/pxf/archive/refs/tags"
ARG PXF_VERSION="6.15.0"
ARG GPBACKUP_DOWNLOAD_URL="https://github.com/GreengageDB/gpbackup/archive/refs/tags"
ARG GPBACKUP_VERSION="1.31.1"
ARG GPBACKUP_S3_PLUGIN_DOWNLOAD_URL="https://github.com/GreengageDB/gpbackup-s3-plugin/archive/refs/tags"
ARG GPBACKUP_S3_PLUGIN_VERSION="1.11.0"
ARG GPBACKMAN_DOWNLOAD_URL="https://github.com/woblerr/gpbackman/archive/refs/tags"
ARG GPBACKMAN_VERSION="v0.10.0"
ARG WALG_DOWNLOAD_URL="https://github.com/wal-g/wal-g"
# Wait new WAL-G release
ARG WALG_VERSION="e4843b849ca05a27655794888341de2662035853"
ARG GOSU_VERSION="1.19"
ARG ZSTD_VERSION="1.5.7"
ARG ZSTD_DOWNLOAD_URL="https://github.com/facebook/zstd/archive/refs/tags"

FROM oraclelinux:${OL_VERSION} AS builder

ARG LIBSIGAR_DOWNLOAD_URL
ARG LIBSIGAR_COMMIT_HASH
ARG GPDB_REPO_URL
ARG GPDB_VERSION
ARG DISKQUOTA_DOWNLOAD_URL
ARG DISKQUOTA_VERSION
ARG ZSTD_VERSION
ARG ZSTD_DOWNLOAD_URL

# Enable EPEL and Oracle CodeReady repositories
RUN dnf -y install \
        oracle-epel-release-el8 \
        dnf-plugins-core \
    && dnf config-manager --set-enabled \
        ol8_codeready_builder \
        ol8_developer_EPEL \
    && dnf -y update \
    && dnf -y install \
        bison \
        ccache \
        cmake \
        curl \
        flex \
        git-core \
        gcc \
        gcc-c++ \
        gcc-toolset-11-gcc \
        iputils \
        binutils \
        krb5-server \
        krb5-workstation \
        apr-devel \
        apr-util-devel \
        bzip2-devel \
        libcurl-devel \
        libevent-devel \
        krb5-devel \
        pam-devel \
        perl-devel \
        perl-ExtUtils-Embed \
        readline-devel \
        openssl-devel \
        libuv-devel \
        # Use standard xerces-c-devel package (see comment on the top of the file)
        xerces-c-devel \
        libxml2-devel \
        libyaml-devel \
        # libzstd-devel \
        zlib-devel \
        openldap-devel \
        libuuid-devel \
        glibc-langpack-en \
        glibc-locale-source \
        net-tools \
        ninja-build \
        openssh-clients \
        openssh-server \
        openssl \
        python2 \
        python2-devel \
        sudo \
        java-17-openjdk-devel \
        wget \
        brotli-devel \
        libsodium-devel \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && echo -e "/usr/local/lib\n/usr/local/lib64\n" >> /etc/ld.so.conf.d/local.conf \
    && ldconfig

# python2.7
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output /tmp/get-pip.py \
    && python2 /tmp/get-pip.py \
    && pip2 install \
        pyyaml==5.3.1 \
        conan==1.48.2 \
        psutil==5.9.6 \
        setuptools==36.6.0 \
        future==1.0.0 \
    && ln -s /usr/bin/python2 /usr/bin/python \
    && rm -rf /tmp/get-pip.py

# zstd (for static library)
RUN wget ${ZSTD_DOWNLOAD_URL}/v${ZSTD_VERSION}.tar.gz -O /tmp/zstd-${ZSTD_VERSION}.tar.gz \
    && mkdir -p /tmp/zstd \
    && tar -xzf /tmp/zstd-${ZSTD_VERSION}.tar.gz --strip-components=1 -C /tmp/zstd \
    && cd /tmp/zstd \
    && make -j2 \
    && make install prefix=/usr/local \
    && ldconfig \
    && rm -rf \
        /tmp/zstd \
        /tmp/zstd-${ZSTD_VERSION}.tar.gz

# libsigar
RUN git clone ${LIBSIGAR_DOWNLOAD_URL} /tmp/sigar \
    && cd /tmp/sigar \
    && git checkout ${LIBSIGAR_COMMIT_HASH} \
    && mkdir -p /tmp/sigar/build \
    && cd /tmp/sigar/build \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr/local .. \
    && make -j2 \
    && make install \
    && ldconfig \
    && rm -rf /tmp/sigar

# greengage
# Use git clone with --recurse-submodules to include PyGreSQL and other submodules
RUN git clone --depth 1 --branch ${GPDB_VERSION} --recurse-submodules ${GPDB_REPO_URL} /tmp/gpdb \
    && cd /tmp/gpdb \
    && echo "${GPDB_VERSION} build dev" > /tmp/gpdb/VERSION \
    && PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}" \
        ./configure --prefix=/usr/local/greenplum-db \
        --enable-ic-proxy \
        --enable-gpperfmon \
        --with-openssl \
        --with-perl \
        --with-python \
        --with-ldap \
        --with-pam \
        --with-libxml \
        --with-gssapi \
        --with-pythonsrc-ext \
        --with-uuid=e2fs \
    && make -j2 \
    && make install \
    # Create symlink greenplum_path.sh -> greengage_path.sh
    # https://github.com/GreengageDB/greengage/commit/75eb38e283ebb0ccd8c9b795345211508fbc548f
    # greenplum_path.sh was renamed to greengage_path.sh
    # For now, it's enough to create a symlink for compatibility
    && ln -s /usr/local/greenplum-db/greengage_path.sh /usr/local/greenplum-db/greenplum_path.sh \
    && rm -rf /tmp/gpdb

# diskquota
RUN wget ${DISKQUOTA_DOWNLOAD_URL}/${DISKQUOTA_VERSION}.tar.gz -O /tmp/diskquota-${DISKQUOTA_VERSION}.tar.gz \
    && mkdir -p /tmp/diskquota \
    && tar -xzf /tmp/diskquota-${DISKQUOTA_VERSION}.tar.gz --strip-components=1 -C /tmp/diskquota \
    && mkdir -p /tmp/diskquota/build \
    && cd /tmp/diskquota/build \
    && cmake /tmp/diskquota \
         -DPG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
         -DDISKQUOTA_DDL_CHANGE_CHECK=off \
         -DCMAKE_BUILD_TYPE=Release \
    && make install \
    && rm -rf \
        /tmp/diskquota \
        /tmp/diskquota-${DISKQUOTA_VERSION}.tar.gz

FROM builder AS go_builder
ARG GOLANG_VERSION
ARG GPBACKUP_DOWNLOAD_URL
ARG GPBACKUP_VERSION
ARG GPBACKUP_S3_PLUGIN_DOWNLOAD_URL
ARG GPBACKUP_S3_PLUGIN_VERSION
ARG GPBACKMAN_DOWNLOAD_URL
ARG GPBACKMAN_VERSION
ARG PXF_DOWNLOAD_URL
ARG PXF_VERSION
ARG WALG_DOWNLOAD_URL
ARG WALG_VERSION

RUN mkdir -p /opt/go \
    && arch="$(uname -m)" \
    && case "${arch}" in \
        aarch64) dpkgArch='arm64' ;; \
        x86_64) dpkgArch='amd64' ;; \
        *) echo >&2 "error: unknown/unsupported architecture '${arch}'"; exit 1 ;; \
    esac \
    && wget https://go.dev/dl/go${GOLANG_VERSION}.linux-${dpkgArch}.tar.gz \
    && tar -xvf go${GOLANG_VERSION}.linux-${dpkgArch}.tar.gz -C /usr/local

ENV PATH="$PATH:/usr/local/go/bin"
ENV GOPATH=/opt/go

# gpbackup/gprestore
RUN wget ${GPBACKUP_DOWNLOAD_URL}/${GPBACKUP_VERSION}.tar.gz -O /tmp/gpbackup-${GPBACKUP_VERSION}.tar.gz \
    && mkdir -p /tmp/gpbackup /tmp/cache \
    && tar -xzf /tmp/gpbackup-${GPBACKUP_VERSION}.tar.gz --strip-components=1 -C /tmp/gpbackup \
    && cd /tmp/gpbackup \
    && make depend \
    && make build GIT_VERSION=${GPBACKUP_VERSION}

# gpbackup-s3-plugin
RUN wget ${GPBACKUP_S3_PLUGIN_DOWNLOAD_URL}/${GPBACKUP_S3_PLUGIN_VERSION}.tar.gz -O /tmp/gpbackup-s3-plugin-${GPBACKUP_S3_PLUGIN_VERSION}.tar.gz \
    && mkdir -p /tmp/gpbackup-s3-plugin \
    && tar -xzf /tmp/gpbackup-s3-plugin-${GPBACKUP_S3_PLUGIN_VERSION}.tar.gz --strip-components=1 -C /tmp/gpbackup-s3-plugin \
    && cd /tmp/gpbackup-s3-plugin \
    && make build GIT_VERSION=${GPBACKUP_S3_PLUGIN_VERSION}

# gpbackman
RUN wget ${GPBACKMAN_DOWNLOAD_URL}/${GPBACKMAN_VERSION}.tar.gz -O /tmp/gpbackman-${GPBACKMAN_VERSION}.tar.gz \
    && mkdir -p /tmp/gpbackman \
    && tar -xzf /tmp/gpbackman-${GPBACKMAN_VERSION}.tar.gz --strip-components=1 -C /tmp/gpbackman \
    && cd /tmp/gpbackman \
    && make build

## wal-g
## Don't use USE_LZO=1, there is no need to build with WAL-E compatibility
## See https://github.com/wal-g/wal-g/issues/1412#issuecomment-1401890162
RUN git clone ${WALG_DOWNLOAD_URL} /tmp/wal-g \
    && cd /tmp/wal-g \
    && git checkout ${WALG_VERSION} \
    && USE_BROTLI=1 \
       USE_LIBSODIUM=1 \
       make deps \
    && USE_BROTLI=1 \
       USE_LIBSODIUM=1 \
       make gp_build

# pxf
# Build pxf without tests
# Components: external-table, cli, server
# fdw extension is not needed for gpdb 6
RUN wget ${PXF_DOWNLOAD_URL}/${PXF_VERSION}.tar.gz -O /tmp/pxf-${PXF_VERSION}.tar.gz \
    && mkdir -p /tmp/pxf \
    && tar -xzf /tmp/pxf-${PXF_VERSION}.tar.gz --strip-components=1 -C /tmp/pxf \
    && cd /tmp/pxf \
    && GPHOME=/usr/local/greenplum-db \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
       PXF_HOME=/usr/local/pxf \
       make -j2 -C external-table install \
    && GPHOME=/usr/local/greenplum-db \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
       PXF_HOME=/usr/local/pxf \
       make -j2 -C cli install \
    && GPHOME=/usr/local/greenplum-db \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
       PXF_HOME=/usr/local/pxf \
       make -j2 -C server install-server \
    && rm -rf \
        /tmp/pxf \
        /tmp/pxf-${PXF_VERSION}.tar.gz

FROM oraclelinux:${OL_VERSION} AS final

ARG REPO_BUILD_TAG
ARG GPDB_VERSION
ARG GOSU_VERSION

ENV TZ="Etc/UTC" \
    GREENPLUM_USER="gpadmin" \
    GREENPLUM_UID=1001 \
    GREENPLUM_GROUP="gpadmin" \
    GREENPLUM_GID=1001 \
    GREENPLUM_DEPLOYMENT="singlenode" \
    GREENPLUM_DATA_DIRECTORY="/data" \
    GREENPLUM_SEG_PREFIX="gpseg" \
    GREENPLUM_DATABASE_NAME="demo" \
    GREENPLUM_GPPERFMON_ENABLE="false" \
    GREENPLUM_DISKQUOTA_ENABLE="false" \
    GREENPLUM_PXF_ENABLE="false" \
    GREENPLUM_WALG_ENABLE="false"

# Install runtime dependencies
RUN dnf -y install \
        oracle-epel-release-el8 \
        dnf-plugins-core \
    && dnf config-manager --set-enabled \
        ol8_codeready_builder \
        ol8_developer_EPEL \
    && dnf -y update \
    && dnf -y install \
        apr \
        apr-util \
        bzip2-libs \
        libcurl \
        libevent \
        krb5-libs \
        pam \
        readline \
        openssl-libs \
        libuv \
        # Use standard xerces-c package (see comment on the top of the file)
        xerces-c \
        libxml2 \
        libyaml \
        # It's enough to have only shared library for zstd at runtime
        libzstd \
        zlib \
        openldap \
        iputils \
        krb5-server \
        krb5-workstation \
        libuuid \
        openssh-clients \
        openssh-server \
        openssl \
        binutils \
        perl \
        rsync \
        curl \
        sed \
        tar \
        zip \
        net-tools \
        less \
        glibc-langpack-en \
        glibc-locale-source \
        iproute \
        python2 \
        sudo \
        wget \
        hostname \
        ca-certificates \
        tzdata \
        java-17-openjdk-headless \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# python2.7 runtime dependencies
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output /tmp/get-pip.py \
    && python2 /tmp/get-pip.py \
    && pip2 install --no-cache-dir \
        future==1.0.0 \
    && rm -rf \ 
      /tmp/get-pip.py \
      /root/.cache/pip

# Grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
# https://github.com/tianon/gosu/blob/master/INSTALL.md
RUN arch="$(uname -m)" \
    && case "${arch}" in \
            aarch64) dpkgArch='arm64' ;; \
            x86_64) dpkgArch='amd64' ;; \
            *) echo >&2 "error: unknown/unsupported architecture '${arch}'"; exit 1 ;; \
        esac \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${dpkgArch}" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${dpkgArch}.asc" \
    # Verify the signature
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    # Verify that the binary works
    && gosu --version \
    && gosu nobody true

RUN groupadd --gid ${GREENPLUM_GID} ${GREENPLUM_GROUP} \
    && useradd --shell /bin/bash --uid ${GREENPLUM_UID} --gid ${GREENPLUM_GID} -m ${GREENPLUM_USER} \
    && localedef -i en_US -f UTF-8 en_US.UTF-8 \
    && mkdir -m 700 -p /home/${GREENPLUM_USER}/.ssh \
    && ssh-keygen -f /home/${GREENPLUM_USER}/.ssh/id_rsa -t rsa -N "" \
    && echo "HostKeyAlgorithms +ssh-rsa" >> /etc/ssh/sshd_config \
    && echo "PubkeyAcceptedKeyTypes +ssh-rsa" >> /etc/ssh/sshd_config \
    && echo "${GREENPLUM_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "source /usr/local/greenplum-db/greenplum_path.sh" > /home/${GREENPLUM_USER}/.bashrc \
    && echo "export JAVA_HOME=/usr/lib/jvm/jre-17-openjdk" >> /home/${GREENPLUM_USER}/.bashrc \
    && echo 'export PATH="/usr/local/pxf/bin:${PATH}"' >> /home/${GREENPLUM_USER}/.bashrc \
    && echo "export PXF_BASE=${GREENPLUM_DATA_DIRECTORY}/pxf" >> /home/${GREENPLUM_USER}/.bashrc \
    && mkdir -p ${GREENPLUM_DATA_DIRECTORY} \
                ${GREENPLUM_DATA_DIRECTORY}/pxf \
                /docker-entrypoint-initdb.d \
    && chown -R ${GREENPLUM_USER}:${GREENPLUM_GROUP} \
        /home/${GREENPLUM_USER}/ \
        ${GREENPLUM_DATA_DIRECTORY} \
        /docker-entrypoint-initdb.d \
    && ln -s /usr/bin/python2 /usr/bin/python \
    && unlink /etc/localtime \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone

COPY --chown=${GREENPLUM_USER}:${GREENPLUM_GROUP} --from=go_builder /usr/local/greenplum-db /usr/local/greenplum-db
COPY --chown=${GREENPLUM_USER}:${GREENPLUM_GROUP} --from=builder \
    /usr/local/lib/libsigar.so \
    /usr/local/greenplum-db/lib/
COPY --chown=${GREENPLUM_USER}:${GREENPLUM_GROUP} --from=go_builder \
    /opt/go/bin/gpbackup \
    /opt/go/bin/gprestore \
    /opt/go/bin/gpbackup_helper \
    /usr/local/greenplum-db/bin/
COPY --chown=${GREENPLUM_USER}:${GREENPLUM_GROUP} --from=go_builder /opt/go/bin/gpbackup_s3_plugin /usr/local/greenplum-db/bin/gpbackup_s3_plugin
COPY --chown=${GREENPLUM_USER}:${GREENPLUM_GROUP} --from=go_builder /usr/local/pxf /usr/local/pxf
COPY --chown=${GREENPLUM_USER}:${GREENPLUM_GROUP} --from=go_builder /tmp/gpbackman/gpbackman /usr/local/greenplum-db/bin/gpbackman
COPY --chown=${GREENPLUM_USER}:${GREENPLUM_GROUP} --from=go_builder /tmp/wal-g/main/gp/wal-g /usr/local/greenplum-db/bin/wal-g
COPY --chmod=755 docker/files/entrypoint.sh /entrypoint.sh
COPY --chmod=755 docker/files/start_gpdb.sh /start_gpdb.sh

LABEL \
    org.opencontainers.image.version="${REPO_BUILD_TAG}" \
    org.opencontainers.image.source="https://github.com/woblerr/docker-greenplum"

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/start_gpdb.sh"]
