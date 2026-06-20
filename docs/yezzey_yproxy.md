# Yezzey and Yproxy

This document describes how to use Yezzey and Yproxy in the open-gpdb image. This functionality is available **only** for open-gpdb image.

## Overview

[Yezzey](https://github.com/open-gpdb/yezzey) is a Greenplum extension that allows offloading data from Append-Optimized (AO) and Append-Optimized Column-Oriented (AOCS) tables to S3-compatible storage. This enables:

- Reducing load on local storage.
- Working with data stored in S3 transparently for applications.
- Saving costs on storing infrequently accessed data.

[Yproxy](https://github.com/open-gpdb/yproxy) is a proxy service that provides communication between Yezzey and S3-compatible storage via Unix socket.

## Requirements

- `opengpdb` image (e.g., `opengpdb:6.29.8`).
- S3-compatible storage.
- `yproxy.yaml` configuration file.

## Configuration

### Environment Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `GREENPLUM_YEZZEY_ENABLE` | Enable Yezzey and Yproxy | `false` |

When `GREENPLUM_YEZZEY_ENABLE=true`:
- Yezzey extension is automatically added to `shared_preload_libraries`.
- Yezzey extension is created in the database specified in `GREENPLUM_DATABASE_NAME`.
- Yproxy service starts automatically.

### yproxy.yaml Configuration File

The `yproxy.yaml` configuration file must be mounted into the container at `/data/yproxy.yaml`.

Example configuration:

```yaml
socket_path: "/tmp/yproxy.sock"
storage:
  storage_endpoint: "http://minio:9000"
  storage_bucket: "yezzey"
  storage_prefix: ""
  storage_region: "us-west-1"
  access_key_id: "demo"
  secret_access_key: "demoBackup"

logging:
  level: "info"
  format: "json"
  output: "/data/yproxy.log"
```

## Running

### Singlenode

```bash
docker run -p 5432:5432 \
  -e GREENPLUM_PASSWORD=gparray \
  -e GREENPLUM_YEZZEY_ENABLE=true \
  -v $(pwd)/yproxy.yaml:/data/yproxy.yaml \
  -d opengpdb:6.29.8
```

### Multi-node Cluster

When deploying a cluster with master and segment hosts, you need to:

1. Set `GREENPLUM_YEZZEY_ENABLE=true` on all cluster nodes.
2. Mount `yproxy.yaml` to all cluster nodes at `/data/yproxy.yaml`.

Example for master:

```yaml
services:
  master:
    image: opengpdb:6.29.8
    environment:
      - GREENPLUM_DEPLOYMENT=master
      - GREENPLUM_YEZZEY_ENABLE=true
      - GREENPLUM_PASSWORD_FILE=/run/secrets/gpdb_password
    volumes:
      - ./yproxy.yaml:/data/yproxy.yaml
```

Example for segment:

```yaml
services:
  segment1:
    image: opengpdb:6.29.8
    command: /start_gpdb.sh "00:primary" "01:primary"
    environment:
      - GREENPLUM_DEPLOYMENT=segment
      - GREENPLUM_YEZZEY_ENABLE=true
    volumes:
      - ./yproxy.yaml:/data/yproxy.yaml
```

Full docker-compose configuration example with Yezzey: [e2e-tests/docker-compose.yezzey.yml](../e2e-tests/docker-compose.yezzey.yml).

## Logs and Debugging

### Yproxy Logs

Yproxy logs are written to the file specified in configuration (default `/data/yproxy.log`):

```bash
docker exec master cat /data/yproxy.log
```

### Checking Yproxy Status

Verify that Yproxy is running:

```bash
docker exec master ls -la /tmp/yproxy.sock
```

### yp-client Utility

The image includes `yp-client` utility for debugging Yproxy interactions:

```bash
docker exec master yp-client --help
```

## E2E Tests

Full Yezzey usage example is provided in e2e tests:

- Docker Compose configuration: [e2e-tests/docker-compose.yezzey.yml](../e2e-tests/docker-compose.yezzey.yml)
- Test script: [e2e-tests/scripts/e2e-yezzey-test.sh](../e2e-tests/scripts/e2e-yezzey-test.sh)
- Yproxy configuration: [e2e-tests/yezzey/yproxy.yaml](../e2e-tests/yezzey/yproxy.yaml)
- SQL initialization script: [e2e-tests/yezzey/init_scripts/yezzey_init.sql](../e2e-tests/yezzey/init_scripts/yezzey_init.sql)

### Running Tests

```bash
make test-e2e-yezzey
```

Or manually:

```bash
cd e2e-tests
docker compose -f docker-compose.s3.yml -f docker-compose.yezzey.yml up -d
GREENPLUM_PASSWORD=$(cat ../docker-compose/secrets/gpdb_password) ./scripts/e2e-yezzey-test.sh
docker compose -f docker-compose.s3.yml -f docker-compose.yezzey.yml down
```

### What Tests Verify

1. **AO tables:**
   - Data offload to S3.
   - Data accessibility after offload.
   - DELETE and VACUUM on offloaded table.
   - Loading data back to local storage.
   - Re-offload and VACUUM (YEZZEY).

2. **AOCS tables:**
   - Same set of operations for column-oriented tables.
