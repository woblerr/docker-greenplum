ARG REPO_BUILD_TAG
ARG UBUNTU_VERSION="22.04"
ARG GOLANG_VERSION="1.25.14"
ARG GPXERCES_DOWNLOAD_URL="https://github.com/woblerr/gp-xerces/archive/refs/tags"
ARG GPXERCES_VERSION="v3.1.2-p1"
ARG LIBSIGAR_DOWNLOAD_URL="https://github.com/boundary/sigar"
ARG LIBSIGAR_COMMIT_HASH="e8961a6674cc4d292e61b353b5c36bfc345434cc"
ARG GPDB_DOWNLOAD_URL="https://github.com/woblerr/gpdb/archive/refs/tags"
ARG GPDB_VERSION="6.27.1"
ARG DISKQUOTA_DOWNLOAD_URL="https://github.com/woblerr/diskquota/archive/refs/tags"
ARG DISKQUOTA_VERSION="2.3.0"
ARG PXF_DOWNLOAD_URL="https://github.com/woblerr/pxf/archive/refs/tags"
ARG PXF_VERSION="release-6.10.1"
ARG GPBACKUP_DOWNLOAD_URL="https://github.com/woblerr/gpbackup/archive/refs/tags"
ARG GPBACKUP_VERSION="1.30.5"
ARG GPBACKUP_S3_PLUGIN_DOWNLOAD_URL="https://github.com/woblerr/gpbackup-s3-plugin/archive/refs/tags"
ARG GPBACKUP_S3_PLUGIN_VERSION="1.10.2"
ARG GPBACKMAN_DOWNLOAD_URL="https://github.com/woblerr/gpbackman/archive/refs/tags"
ARG GPBACKMAN_VERSION="v0.13.0"
ARG WALG_DOWNLOAD_URL="https://github.com/wal-g/wal-g"
# Wait new WAL-G release
ARG WALG_VERSION="v3.0.9"

FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG GPXERCES_DOWNLOAD_URL
ARG GPXERCES_VERSION
ARG LIBSIGAR_DOWNLOAD_URL
ARG LIBSIGAR_COMMIT_HASH
ARG GPDB_DOWNLOAD_URL
ARG GPDB_VERSION
ARG DISKQUOTA_DOWNLOAD_URL
ARG DISKQUOTA_VERSION

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        bison \
        ccache \
        cmake \
        curl \
        flex \
        git-core \
        gcc \
        g++ \
        inetutils-ping \
        binutils \
        krb5-kdc \
        krb5-admin-server \
        libaprutil1-dev \
        libapr1-dev \
        libbz2-dev \
        libcurl4-gnutls-dev \
        libevent-dev \
        libkrb5-dev \
        libpam-dev \
        libperl-dev \
        libreadline-dev \
        libssl-dev \
        libuv1-dev \
        libxml2-dev \
        libyaml-dev \
        libzstd-dev \
        zlib1g-dev \
        libldap-dev \
        libossp-uuid-dev \
        krb5-kdc \
        krb5-admin-server \
        locales \
        net-tools \
        ninja-build \
        openssh-client \
        openssh-server \
        openssl \
        python2.7 \
        python2.7-dev \
        git \
        sudo \
        openjdk-11-jdk \
        libbrotli-dev \
        libsodium-dev \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo -e "/usr/local/lib\n/usr/local/lib64\n" >> /etc/ld.so.conf.d/local.conf \
    && ldconfig

# python2.7
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output /tmp/get-pip.py \
    && python2.7 /tmp/get-pip.py \
    && pip2.7 install \
        pyyaml==5.3.1 \
        conan==1.48.2 \
        psutil==5.9.6 \
        setuptools==36.6.0 \
    && ln -s /usr/bin/python2.7 /usr/bin/python \
    && rm -rf /tmp/get-pip.py

# xerces-c
RUN wget ${GPXERCES_DOWNLOAD_URL}/${GPXERCES_VERSION}.tar.gz -O /tmp/gp-xerces-${GPXERCES_VERSION}.tar.gz \
    && mkdir -p /tmp/gp-xerces \
    && tar -xzf /tmp/gp-xerces-${GPXERCES_VERSION}.tar.gz --strip-components=1 -C /tmp/gp-xerces \
    && cd /tmp/gp-xerces \
    && ./configure --prefix=/usr/local \
    && make -j2 \
    && make install \
    && rm -rf \
        /tmp/gp-xerces \
        /tmp/gp-xerces-${GPXERCES_VERSION}.tar.gz

# libsigar
RUN git clone ${LIBSIGAR_DOWNLOAD_URL} /tmp/sigar \
    && cd /tmp/sigar \
    && git checkout ${LIBSIGAR_COMMIT_HASH} \
    && mkdir -p /tmp/sigar/build \
    && cd /tmp/sigar/build \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr/local .. \
    && make -j2 \
    && make install \
    && rm -rf /tmp/sigar

# greenplum
RUN wget ${GPDB_DOWNLOAD_URL}/${GPDB_VERSION}.tar.gz -O /tmp/gpdb-${GPDB_VERSION}.tar.gz \
    && mkdir -p /tmp/gpdb \
    && tar -xzf /tmp/gpdb-${GPDB_VERSION}.tar.gz --strip-components=1 -C /tmp/gpdb \
    && cd /tmp/gpdb \
    && echo "${GPDB_VERSION} build dev" > /tmp/gpdb/VERSION \
    && ./configure --prefix=/usr/local/greenplum-db \
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
    && rm -rf \
        /tmp/gpdb \
        /tmp/gpdb-${GPDB_VERSION}.tar.gz

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
    && wget https://go.dev/dl/go${GOLANG_VERSION}.linux-$(dpkg --print-architecture).tar.gz \
    && tar -xvf go${GOLANG_VERSION}.linux-$(dpkg --print-architecture).tar.gz -C /usr/local

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

# wal-g
# Don't use USE_LZO=1, there is no need to build with WAL-E compatibility
# See https://github.com/wal-g/wal-g/issues/1412#issuecomment-1401890162
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
    && PXF_HOME=/usr/local/pxf \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
       make -j2 -C external-table install \
    && PXF_HOME=/usr/local/pxf \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
       make -j2 -C cli install \
    && PXF_HOME=/usr/local/pxf \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
       make -j2 -C server install-server \
    && rm -rf \
        /tmp/pxf \
        /tmp/pxf-${PXF_VERSION}.tar.gz

FROM ubuntu:${UBUNTU_VERSION} AS final

ARG REPO_BUILD_TAG
ARG GPDB_VERSION

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

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        libapr1 \
        libaprutil1 \
        libbz2-1.0 \
        libcurl3-gnutls \
        libcurl4 \
        libevent-2.1-7 \
        libkrb5-3 \
        libpam0g \
        libreadline8 \
        libssl3 \
        libuv1 \
        libxml2 \
        libyaml-0-2 \
        libzstd1 \
        zlib1g \
        libldap-2.5-0 \
        inetutils-ping \
        krb5-kdc \
        krb5-admin-server \
        uuid-runtime \
        openssh-client \
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
        locales \
        iproute2 \
        python2.7 \
        gosu \
        ca-certificates \
        tzdata \
        openjdk-11-jre \
        fakeroot \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid ${GREENPLUM_GID} ${GREENPLUM_GROUP} \
    && useradd --shell /bin/bash --uid ${GREENPLUM_UID} --gid ${GREENPLUM_GID} -m ${GREENPLUM_USER} \
    && locale-gen en_US.UTF-8 \
    && mkdir -m 700 -p /home/${GREENPLUM_USER}/.ssh \
    && ssh-keygen -f /home/${GREENPLUM_USER}/.ssh/id_rsa -t rsa -N "" \
    && echo "HostKeyAlgorithms +ssh-rsa" >> /etc/ssh/sshd_config \
    && echo "PubkeyAcceptedKeyTypes +ssh-rsa" >> /etc/ssh/sshd_config \
    && echo "${GREENPLUM_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "source /usr/local/greenplum-db/greenplum_path.sh" > /home/${GREENPLUM_USER}/.bashrc \
    && arch="$(dpkg --print-architecture)" \
    && case "${arch}" in \
        arm64) echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-arm64" >> /home/${GREENPLUM_USER}/.bashrc ;; \
        amd64) echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /home/${GREENPLUM_USER}/.bashrc ;; \
        *) echo >&2 "error: unknown/unsupported architecture '${arch}'"; exit 1 ;; \
    esac \
    && echo 'export PATH="/usr/local/pxf/bin:${PATH}"' >> /home/${GREENPLUM_USER}/.bashrc \
    && echo "export PXF_BASE=${GREENPLUM_DATA_DIRECTORY}/pxf" >> /home/${GREENPLUM_USER}/.bashrc \
    && mkdir -p ${GREENPLUM_DATA_DIRECTORY} \
                ${GREENPLUM_DATA_DIRECTORY}/pxf \
                /docker-entrypoint-initdb.d \
    && chown -R ${GREENPLUM_USER}:${GREENPLUM_GROUP} \
        /home/${GREENPLUM_USER}/ \
        ${GREENPLUM_DATA_DIRECTORY} \
        /docker-entrypoint-initdb.d \
    && ln -s /usr/bin/python2.7 /usr/bin/python \
    && unlink /etc/localtime \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone

COPY --chown=${GREENPLUM_USER}:${GREENPLUM_GROUP} --from=go_builder /usr/local/greenplum-db /usr/local/greenplum-db
COPY --chown=${GREENPLUM_USER}:${GREENPLUM_GROUP} --from=builder \
    /usr/local/lib/libxerces-c.so \
    /usr/local/lib/libxerces-c-3.1.so \
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
