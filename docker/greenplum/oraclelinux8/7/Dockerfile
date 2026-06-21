ARG REPO_BUILD_TAG
ARG OL_VERSION="8"
ARG GOLANG_VERSION="1.25.11"
ARG GPXERCES_DOWNLOAD_URL="https://github.com/woblerr/gp-xerces/archive/refs/tags"
ARG GPXERCES_VERSION="v3.1.2-p1"
ARG GPDB_DOWNLOAD_URL="https://github.com/woblerr/gpdb/archive/refs/tags"
ARG GPDB_VERSION="7.1.0"
ARG DISKQUOTA_DOWNLOAD_URL="https://github.com/woblerr/diskquota/archive/refs/tags"
ARG DISKQUOTA_VERSION="2.3.0"
ARG PXF_DOWNLOAD_URL="https://github.com/woblerr/pxf/archive/refs/tags"
ARG PXF_VERSION="release-6.10.1"
ARG GPBACKUP_DOWNLOAD_URL="https://github.com/woblerr/gpbackup/archive/refs/tags"
ARG GPBACKUP_VERSION="1.30.5"
ARG GPBACKUP_S3_PLUGIN_DOWNLOAD_URL="https://github.com/woblerr/gpbackup-s3-plugin/archive/refs/tags"
ARG GPBACKUP_S3_PLUGIN_VERSION="1.10.2"
ARG GPBACKMAN_DOWNLOAD_URL="https://github.com/woblerr/gpbackman/archive/refs/tags"
ARG GPBACKMAN_VERSION="v0.10.0"
ARG WALG_DOWNLOAD_URL="https://github.com/wal-g/wal-g"
# Wait new WAL-G release
ARG WALG_VERSION="3c54030dda939d21a04adf9402adf9f45ce3d547"
ARG GOSU_VERSION="1.19"

FROM oraclelinux:${OL_VERSION} AS builder

ARG GPXERCES_DOWNLOAD_URL
ARG GPXERCES_VERSION
ARG GPDB_DOWNLOAD_URL
ARG GPDB_VERSION
ARG DISKQUOTA_DOWNLOAD_URL
ARG DISKQUOTA_VERSION

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
        libxml2-devel \
        libyaml-devel \
        libzstd-devel \
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
        python3 \
        python3-devel \
        python3-pip \
        python3-psutil \
        python3-psycopg2 \
        python3-setuptools \
        python3-pyyaml \
        sudo \
        java-11-openjdk-devel \
        wget \
        brotli-devel \
        libsodium-devel \
   #     pkg-config \
   #     postgresql-devel \
   # && pip3 install --no-cache-dir PyGreSQL \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && echo -e "/usr/local/lib\n/usr/local/lib64\n" >> /etc/ld.so.conf.d/local.conf \
    && ldconfig

# xerces-c
RUN wget ${GPXERCES_DOWNLOAD_URL}/${GPXERCES_VERSION}.tar.gz -O /tmp/gp-xerces-${GPXERCES_VERSION}.tar.gz \
    && mkdir -p /tmp/gp-xerces \
    && tar -xzf /tmp/gp-xerces-${GPXERCES_VERSION}.tar.gz --strip-components=1 -C /tmp/gp-xerces \
    && cd /tmp/gp-xerces \
    && ./configure --prefix=/usr/local \
    && make -j2 \
    && make install \
    && ldconfig \
    && rm -rf \
        /tmp/gp-xerces \
        /tmp/gp-xerces-${GPXERCES_VERSION}.tar.gz

# greenplum
RUN wget ${GPDB_DOWNLOAD_URL}/${GPDB_VERSION}.tar.gz -O /tmp/gpdb-${GPDB_VERSION}.tar.gz \
    && mkdir -p /tmp/gpdb \
    && tar -xzf /tmp/gpdb-${GPDB_VERSION}.tar.gz --strip-components=1 -C /tmp/gpdb \
    && cd /tmp/gpdb \
    && echo "${GPDB_VERSION} build dev" > /tmp/gpdb/VERSION \
    && ./configure --prefix=/usr/local/greenplum-db \
        --enable-ic-proxy \
        --with-openssl \
        --with-perl \
        --with-python \
        --with-ldap \
        --with-pam \
        --with-libxml \
        --with-gssapi \
        --with-pythonsrc-ext \
        --with-uuid=e2fs \
        --enable-gpfdist \
    && make -j2 \
    && make install \
    && rm -rf \
        /tmp/gpdb \
        /tmp/gpdb-${GPDB_VERSION}.tar.gz

# Now install PyGreSQL after Greenplum is copied
# No available in EPEL
RUN PATH=${PATH}:/usr/local/greenplum-db/bin pip3 install --no-cache-dir PyGreSQL

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
# Components: external-table, fdw, cli, servers
RUN wget ${PXF_DOWNLOAD_URL}/${PXF_VERSION}.tar.gz -O /tmp/pxf-${PXF_VERSION}.tar.gz \
    && mkdir -p /tmp/pxf \
    && tar -xzf /tmp/pxf-${PXF_VERSION}.tar.gz --strip-components=1 -C /tmp/pxf \
    && cd /tmp/pxf \
    && PXF_HOME=/usr/local/pxf \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
       make -j2 -C external-table install \
    && PXF_HOME=/usr/local/pxf \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
       make -j2 -C fdw install \
    && PXF_HOME=/usr/local/pxf \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
       make -j2 -C cli install \
    && PXF_HOME=/usr/local/pxf \
       PG_CONFIG=/usr/local/greenplum-db/bin/pg_config \
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
RUN dnf -y update \
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
        libxml2 \
        libyaml \
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
        python3 \
        python3-pip \
        python3-psutil \
        python3-psycopg2 \
        python3-setuptools \
        python3-pyyaml \
        sudo \
        wget \
        hostname \
        ca-certificates \
        tzdata \
        java-11-openjdk-headless

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
    && echo "export JAVA_HOME=/usr/lib/jvm/jre-11-openjdk" >> /home/${GREENPLUM_USER}/.bashrc \
    && echo 'export PATH="/usr/local/pxf/bin:${PATH}"' >> /home/${GREENPLUM_USER}/.bashrc \
    && echo "export PXF_BASE=${GREENPLUM_DATA_DIRECTORY}/pxf" >> /home/${GREENPLUM_USER}/.bashrc \
    && mkdir -p ${GREENPLUM_DATA_DIRECTORY} \
                ${GREENPLUM_DATA_DIRECTORY}/pxf \
                /docker-entrypoint-initdb.d \
    && chown -R ${GREENPLUM_USER}:${GREENPLUM_GROUP} \
        /home/${GREENPLUM_USER}/ \
        ${GREENPLUM_DATA_DIRECTORY} \
        /docker-entrypoint-initdb.d \
    && unlink /etc/localtime \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone

COPY --from=go_builder /usr/local/greenplum-db /usr/local/greenplum-db
COPY --from=builder \
    /usr/local/lib/libxerces-c.so \
    /usr/local/lib/libxerces-c-3.1.so \
    /usr/local/greenplum-db/lib/

# Install PyGreSQL
RUN dnf -y install gcc python3-devel \
    && PATH=${PATH}:/usr/local/greenplum-db/bin pip3 install --no-cache-dir PyGreSQL \
    && dnf -y remove gcc python3-devel \
    && dnf clean all \
    && rm -rf /var/cache/dnf

COPY --from=go_builder \
    /opt/go/bin/gpbackup \
    /opt/go/bin/gprestore \
    /opt/go/bin/gpbackup_helper \
    /usr/local/greenplum-db/bin/
COPY --from=go_builder /opt/go/bin/gpbackup_s3_plugin /usr/local/greenplum-db/bin/gpbackup_s3_plugin
COPY --from=go_builder /usr/local/pxf /usr/local/pxf
COPY --from=go_builder /tmp/gpbackman/gpbackman /usr/local/greenplum-db/bin/gpbackman
COPY --from=go_builder /tmp/wal-g/main/gp/wal-g /usr/local/greenplum-db/bin/wal-g
COPY --chmod=755 docker/files/entrypoint.sh /entrypoint.sh
COPY --chmod=755 docker/files/start_gpdb.sh /start_gpdb.sh

LABEL \
    org.opencontainers.image.version="${REPO_BUILD_TAG}" \
    org.opencontainers.image.source="https://github.com/woblerr/docker-greenplum"

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/start_gpdb.sh"]