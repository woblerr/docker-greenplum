# docker-greenplum

[![build-gpdb6](https://github.com/woblerr/docker-greenplum/actions/workflows/build-gpdb6.yml/badge.svg)](https://github.com/woblerr/docker-greenplum/actions/workflows/build-gpdb6.yml)
[![build-gpdb7](https://github.com/woblerr/docker-greenplum/actions/workflows/build-gpdb7.yml/badge.svg)](https://github.com/woblerr/docker-greenplum/actions/workflows/build-gpdb7.yml)
[![build-greengage6](https://github.com/woblerr/docker-greenplum/actions/workflows/build-greengage6.yml/badge.svg)](https://github.com/woblerr/docker-greenplum/actions/workflows/build-greengage6.yml)
[![build-greengage7](https://github.com/woblerr/docker-greenplum/actions/workflows/build-greengage7.yml/badge.svg)](https://github.com/woblerr/docker-greenplum/actions/workflows/build-greengage7.yml)
[![build-warehousepg6](https://github.com/woblerr/docker-greenplum/actions/workflows/build-warehousepg6.yml/badge.svg)](https://github.com/woblerr/docker-greenplum/actions/workflows/build-warehousepg6.yml)
[![build-warehousepg7](https://github.com/woblerr/docker-greenplum/actions/workflows/build-warehousepg7.yml/badge.svg)](https://github.com/woblerr/docker-greenplum/actions/workflows/build-warehousepg7.yml)
[![build-opengpdb6](https://github.com/woblerr/docker-greenplum/actions/workflows/build-opengpdb6.yml/badge.svg)](https://github.com/woblerr/docker-greenplum/actions/workflows/build-opengpdb6.yml)

This project provides Docker images for running Greenplum Database (GPDB) and its forks in containers. It supports both single-node and multi-node deployments. The images can be used for development, testing, and learning purposes.

**Supported distributions:**
- Greenplum Database (GPDB)
- [Greengage](https://github.com/GreengageDB/greengage) (GGDB)
- [WarehousePG](https://github.com/warehouse-pg/warehouse-pg) (WHPG)
- [open-gpdb](https://github.com/open-gpdb/gpdb) (OpenGPDB)

For [Apache Cloudberry](https://cloudberry.apache.org/) Docker images, see the [docker-cloudberry](https://github.com/woblerr/docker-cloudberry) repository.

The Greenplum in docker provides the following features:
- single-node deployment;
- master and segments deployment;
- support for segment mirroring;
- gpperfmon (GPDB 6 only);
- diskquota;
- gpbackup/gprestore;
- gpbackup-s3-plugin;
- gpbackman;
- PXF (Platform Extension Framework);
- custom initialization scripts;
- WAL-G (physical backups).

The open-gpdb image contains additional features:
- Yezzey and Yproxy for data offloading to S3.


Environment variables supported by this image:

* `TZ` - container's time zone, default `Etc/UTC`;
* `GREENPLUM_USER` - non-root user name for execution of the command, default `gpadmin`;
* `GREENPLUM_UID` - UID of `${GREENPLUM_USER}` user, default `1001`;
* `GREENPLUM_GROUP` - group name of `${GREENPLUM_USER}` user, default `gpadmin`;
* `GREENPLUM_GID` - GID of `${GREENPLUM_USER}` user, default `1001`;
* `GREENPLUM_DEPLOYMENT` - Greenplum deployment type, default `singlenode`, available values: `singlenode`, `master`, `segment`;
* `GREENPLUM_DATA_DIRECTORY` - Greenplum data directory location, default `/data`;
* `GREENPLUM_SEG_PREFIX` - Greenplum segment prefix, default `gpseg`;
* `GREENPLUM_DATABASE_NAME` - Greenplum database name, default `demo`, this database will be created during the initialization;
* `GREENPLUM_GPPERFMON_ENABLE` - enable gpperfmon (GPDB 6 only), default `false`;
* `GREENPLUM_DISKQUOTA_ENABLE` - enable diskquota, default `false`;
* `GREENPLUM_PXF_ENABLE` - enable PXF, default `false`;
* `GREENPLUM_WALG_ENABLE` - enable WAL-G, default `false`;

Required environment variables:
* `GREENPLUM_PASSWORD` - password for `${GREENPLUM_USER}` user, **required**;
* `GREENPLUM_GPMON_PASSWORD` - password for `gpmon` user, **required** when `GREENPLUM_GPPERFMON_ENABLE` is `true`;

The open-gpdb image support additional environment variables for Yezzey and Yproxy features:

* `GREENPLUM_YEZZEY_ENABLE` - enable Yezzey extension and start Yproxy service for data offloading to S3, default `false`;

## Build matrix

The repository contains information for the last available versions. For specific version, you can build your own image using the [Build](#build) section.

Greenplum 6:
| Image | GPDB Version | Ubuntu 22.04 | Oracle Linux 8 | Platform |
|---|---|---|---| ---|
| greenplum | 6.27.1| `6.27.1`, `6.27.1-ubuntu22.04` | `6.27.1-oraclelinux8` | `linux/amd64`, `linux/arm64` |

Greenplum 7:
| Image | GPDB Version | Ubuntu 22.04 | Oracle Linux 8 | Platform |
|---|---|---|---| ---|
| greenplum | 7.1.0| `7.1.0`, `7.1.0-ubuntu22.04` | `7.1.0-oraclelinux8` |  `linux/amd64`, `linux/arm64` |

Greengage 6:
| Image | Greengage Version | Ubuntu 22.04 | Oracle Linux 8 | Platform |
|---|---|---|---| ---|
| greengage | 6.30.1| `6.30.1`, `6.30.1-ubuntu22.04` | `6.30.1-oraclelinux8` | `linux/amd64`, `linux/arm64` |

Greengage 7:
| Image | Greengage Version | Ubuntu 22.04 | Oracle Linux 8 | Platform |
|---|---|---|---| ---|
| greengage | 7.4.1| `7.4.1`, `7.4.1-ubuntu22.04` | `7.4.1-oraclelinux8` | `linux/amd64`, `linux/arm64` |

WarehousePG 6:
| Image | WarehousePG Version | Ubuntu 22.04 | Oracle Linux 8 | Platform |
|---|---|---|---| ---|
| warehousepg | 6.27.3-WHPG| `6.27.3-WHPG`, `6.27.3-WHPG-ubuntu22.04` | `6.27.3-WHPG-oraclelinux8` | `linux/amd64`, `linux/arm64` |

WarehousePG 7:
| Image | WarehousePG Version | Ubuntu 22.04 | Oracle Linux 8 | Platform |
|---|---|---|---| ---|
| warehousepg | 7.3.1-WHPG| `7.3.1-WHPG`, `7.3.1-WHPG-ubuntu22.04` | `7.3.1-WHPG-oraclelinux8` | `linux/amd64`, `linux/arm64` |

open-gpdb 6:
| Image | open-gpdb Version | Ubuntu 22.04 | Oracle Linux 8 | Platform |
|---|---|---|---| ---|
| opengpdb | 6.29.3| `6.29.3`, `6.29.3-ubuntu22.04` | - | `linux/amd64`, `linux/arm64` |

## Pull
Change `tag` to the version you need.

**Greenplum:**

* Docker Hub:

```bash
docker pull woblerr/greenplum:tag
```

* GitHub Registry:

```bash
docker pull ghcr.io/woblerr/greenplum:tag
```

**Greengage:**

* Docker Hub:

```bash
docker pull woblerr/greengage:tag
```

* GitHub Registry:

```bash
docker pull ghcr.io/woblerr/greengage:tag
```

**WarehousePG:**

* Docker Hub:

```bash
docker pull woblerr/warehousepg:tag
```

* GitHub Registry:

```bash
docker pull ghcr.io/woblerr/warehousepg:tag
```


**open-gpdb:**

* Docker Hub:

```bash
docker pull woblerr/opengpdb:tag
```

* GitHub Registry:

```bash
docker pull ghcr.io/woblerr/opengpdb:tag
```

## Run

You will need to mount the necessary directories or files inside the container (or use this image to build your own on top of it).

### Simple

```bash
docker run -p 5432:5432 -e GREENPLUM_PASSWORD=gparray -d greenplum:6.27.1
```

Connect to Greenplum:

```bash
psql -h localhost -p 5432 -U gpadmin demo
```

### Docker Secrets
As an alternative to passing sensitive information via environment variables, `_FILE` may be appended to `GREENPLUM_PASSWORD` and `GREENPLUM_GPMON_PASSWORD` environment variables. In particular, this can be used to load passwords from Docker secrets stored in `/run/secrets/<secret_name>` files. 

For example:
```bash
docker run -p 5432:5432 -e GREENPLUM_PASSWORD_FILE=/run/secrets/gpdb_password -d greenplum:6.27.1
```

### Initialization Scripts

The image supports running custom initialization `*.sql` or `*.sh` scripts after Greenplum was started. Place your scripts in the `/docker-entrypoint-initdb.d` directory inside the container.

Scripts in `/docker-entrypoint-initdb.d` are executed only if a container is started with an empty data directory; any pre-existing database will remain untouched when the container is started.

#### Script Execution Process

Scripts are processed as follows:
- **SQL scripts** (`*.sql`): Executed using `psql` with the following options:
  - Executed for the database specified in `GREENPLUM_DATABASE_NAME`.
  - Run with `-v ON_ERROR_STOP=1` flag.
  - Run with `--no-psqlrc`.
  - Connected as the `GREENPLUM_USER`.
- **Shell scripts** (`*.sh`):
  - If the script has executable permissions, it is executed directly.
  - If not executable, it is sourced.
- **Other files**: Files with other extensions are ignored.

Example SQL initialization script `00_init.sql`:

```sql
CREATE TABLE test_initialization (
  id serial PRIMARY KEY,
  name text,
  created_at timestamp DEFAULT current_timestamp
);

INSERT INTO test_initialization (name) VALUES ('Initialized via sql script');
```
Example shell script `01_init.sh`:

```bash
#!/bin/bash
echo "Executing initialization shell script"
psql -U ${GREENPLUM_USER} -h $(hostname) -d ${GREENPLUM_DATABASE_NAME} -c "INSERT INTO test_initialization (name) VALUES ('Added via shell script');"
echo "Shell script executed successfully!"
```

You can mount your initialization scripts directory to the container:

```bash
docker run -p 5432:5432 \
  -e GREENPLUM_PASSWORD=gparray \
  -v $(pwd)/docs/custom_init_scripts:/docker-entrypoint-initdb.d \
  -d greenplum:6.27.1
```

Or build a custom image:

```bash
FROM greenplum:6.27.1
COPY docs/custom_init_scripts/* /docker-entrypoint-initdb.d/
```

#### WAL-G configuration

When `GREENPLUM_WALG_ENABLE=true`, WAL-G is installed and available, but you need to configure it manually or use initialization scripts to set up `archive_command` and other parameters.


```bash
docker run -p 5432:5432 \
  -e GREENPLUM_PASSWORD=gparray \
  -e GREENPLUM_WALG_ENABLE=true \
  -v $(pwd)/wal-g.yaml:/tmp/wal-g.yaml \
  -v $(pwd)/wal-g_init.sh:/docker-entrypoint-initdb.d/wal-g_init.sh \
  -d greenplum:6.27.1
```

Where init scripts for WAL-G looks like:
```bash
#!/bin/bash
echo "Configuring wal-g archive_command"
USER=${GREENPLUM_USER} gpconfig -c archive_command -v "wal-g seg wal-push %p --content-id=%c --config /tmp/wal-g.yaml"
USER=${GREENPLUM_USER} gpconfig -c archive_timeout -v 600 --skipvalidation
USER=${GREENPLUM_USER} gpstop -u
```

#### Yezzey configuration

**Note:** Yezzey is only available for open-gpdb image.

When `GREENPLUM_YEZZEY_ENABLE=true`:
- Yezzey extension is automatically configured and enabled
- Yproxy service starts automatically
- Requires `yproxy.yaml` configuration file mounted at `/data/yproxy.yaml` inside the container.

Quick example:

```bash
docker run -p 5432:5432 \
  -e GREENPLUM_PASSWORD=gparray \
  -e GREENPLUM_YEZZEY_ENABLE=true \
  -v $(pwd)/yproxy.yaml:/data/yproxy.yaml \
  -d opengpdb:6.29.3
```

### Docker Compose
#### Prepare

Prepare password files (**set your own passwords**):
```bash
echo "gparray" > docker-compose/secrets/gpdb_password
echo "changeme" > docker-compose/secrets/gpmon_password
```

For correct start docker compose, configs should be mounted to `/tmp`.
It's valid for `gpinitsystem_config`, `hostfile_gpinitsystem` and `authorized_keys` files.

SSH rsa keys should be mounted to `/home/${GREENPLUM_USER}/.ssh/` directory.
Master mounts:
```yaml
    volumes:
      - ./conf/${CONFIG_FOLDER}/gpinitsystem_config_no_mirrors:/tmp/gpinitsystem_config
      - ./conf/hostfile_gpinitsystem:/tmp/hostfile_gpinitsystem
      - ./conf/ssh/id_rsa:/home/gpadmin/.ssh/id_rsa
      - ./conf/ssh/id_rsa.pub:/home/gpadmin/.ssh/id_rsa.pub
```
Segments mounts:
```yaml
    volumes:
       - ./conf/ssh/authorized_keys:/tmp/authorized_keys
```

The image name, version and `CONFIG_FOLDER` variable should be set in the `.env` file. See the example `.env` file in the `docker-compose` directory.

#### Run
Run  cluster with 1 master and 2 segments without mirroring:
```bash
docker compose -f ./docker-compose/docker-compose.no_mirrors.yaml up -d
```

Run cluster with persistent storage:
```bash
docker compose -f ./docker-compose/docker-compose.no_mirrors_persistent.yaml up -d
```

Run cluster with 1 master and 2 segments with mirroring:
```bash
docker compose -f ./docker-compose/docker-compose.with_mirrors.yaml up -d
```

## Build

**Greenplum:**

For Ubuntu based images:
```bash
make build_gpdb_6_ubuntu TAG_GPDB_6=6.27.1
```
```bash
make build_gpdb_7_ubuntu TAG_GPDB_7=7.1.0
```

For Oracle Linux based images:
```bash
make build_gpdb_6_oraclelinux TAG_GPDB_6=6.27.1
```
```bash
make build_gpdb_7_oraclelinux TAG_GPDB_7=7.1.0
```

**Greengage:**

For Ubuntu based images:
```bash
make build_greengage_6_ubuntu TAG_GREENGAGE_6=6.30.1
```
```bash
make build_greengage_7_ubuntu TAG_GREENGAGE_7=7.4.1
```

For Oracle Linux based images:
```bash
make build_greengage_6_oraclelinux TAG_GREENGAGE_6=6.30.1
```
```bash
make build_greengage_7_oraclelinux TAG_GREENGAGE_7=7.4.1
```

**WarehousePG:**

For Ubuntu based images:
```bash
make build_warehousepg_6_ubuntu TAG_WAREHOUSEPG_6=6.27.3-WHPG
```
```
make build_warehousepg_7_ubuntu TAG_WAREHOUSEPG_7=7.3.1-WHPG
```

For Oracle Linux based images:
```bash
make build_warehousepg_6_oraclelinux TAG_WAREHOUSEPG_6=6.27.3-WHPG
```
```bash
make build_warehousepg_7_oraclelinux TAG_WAREHOUSEPG_7=7.3.1-WHPG
```

**open-gpdb:**

For Ubuntu based images:
```bash
make build_opengpdb_6_ubuntu TAG_OPENGPDB_6=6.29.3
```

**Manual build examples:**

Greenplum simple manual build:
```bash
docker buildx build -f docker/greenplum/ubuntu22.04/6/Dockerfile -t greenplum:6.27.1 .
```

Greengage simple manual build:
```bash
docker buildx build -f docker/greengage/ubuntu22.04/6/Dockerfile -t greengage:6.30.1 .
```
```bash
docker buildx build -f docker/greengage/ubuntu22.04/7/Dockerfile -t greengage:7.4.1 .
```

Greengage OracleLinux manual build:
```bash
docker buildx build -f docker/greengage/oraclelinux8/6/Dockerfile -t greengage:6.30.1-oraclelinux8 .
```
```bash
docker buildx build -f docker/greengage/oraclelinux8/7/Dockerfile -t greengage:7.4.1-oraclelinux8 .
```

WarehousePG simple manual build:
```bash
docker buildx build -f docker/warehousepg/ubuntu22.04/6/Dockerfile -t warehousepg:6.27.3-WHPG .
```
```
docker buildx build -f docker/warehousepg/ubuntu22.04/7/Dockerfile -t warehousepg:7.3.1-WHPG .
```

WarehousePG OracleLinux manual build:
```bash
docker buildx build -f docker/warehousepg/oraclelinux8/6/Dockerfile -t warehousepg:6.27.3-WHPG-oraclelinux8 .
```
```bash
docker buildx build -f docker/warehousepg/oraclelinux8/7/Dockerfile -t warehousepg:7.3.1-WHPG-oraclelinux8 .
```

open-gpdb simple manual build:
```bash
docker buildx build -f docker/opengpdb/ubuntu22.04/6/Dockerfile -t opengpdb:6.29.3 .
```

Manual build with specific component version for `linux/amd64` platform:
```bash
docker buildx build --platform linux/amd64 -f docker/greenplum/ubuntu22.04/6/Dockerfile --build-arg GPDB_VERSION=6.27.1 -t greenplum:6.27.1 .
```

Manual build with specific component versions for `linux/amd64` and `linux/arm64` platforms:
```bash
docker buildx build --platform linux/amd64,linux/arm64 -f docker/greenplum/ubuntu22.04/6/Dockerfile --build-arg GPDB_VERSION=6.27.1 --build-arg DISKQUOTA_VERSION=2.3.0 --build-arg GPBACKUP_VERSION=1.30.5 -t greenplum:6.27.1 .
```

## Running tests
Run the end-to-end tests:
```bash
make test-e2e
```
See [tests description](./e2e-tests/README.md).
