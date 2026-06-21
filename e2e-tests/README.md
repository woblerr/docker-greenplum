# End-to-end tests

The following architecture is used to run the tests:

* Separate containers with Greenplum (GPDB, Greengage, WarehousePG, or open-gpdb).
* Separate containers for MinIO and nginx. Official images [minio/minio](https://hub.docker.com/r/minio/minio), [minio/mc](https://hub.docker.com/r/minio/mc) and [nginx](https://hub.docker.com/_/nginx) are used. It's necessary for S3 compatible storage for WAL archiving and backups.

## Prerequisites

Before running tests:

1. Build Greenplum docker images as described in [Build section](../README.md#build).

2. Configure test environment by editing `e2e-tests/.env` file if needed (default: `GPDB 6.27.1`, other supported: `Greengage`, `WarehousePG`, `open-gpdb`).

3. Prepare password files as described in [Prepare section](../README.md#prepare) for Docker Compose. In tests used ssh keys from `e2e-tests/conf/ssh/` directory, so you can use them or create your own.

## Running tests

Run all tests:
```bash
make test-e2e
``` 

### WAL-G tests

Primary cluster is described in `e2e-tests/docker-compose.gpdb.yml`, standby cluster is described in `e2e-tests/docker-compose.gpdb-restore.yml`, and S3 compatible storage is described in `e2e-tests/docker-compose.s3.yml`.

The test validates WAL-G backup and restore functionality for Greenplum-compatible images with WAL-G support:

1. **Full backup test**:
   - Creates full backup on primary cluster
   - Restores backup on standby cluster
   - Compares data between primary and standby clusters

2. **Restore point test**:
   - Inserts additional data into primary cluster
   - Creates restore point
   - Restores to specific restore point on standby cluster  
   - Compares data between clusters at the restore point

The test verifies that data in tables `walg_ao`, `walg_co`, and `walg_heap` matches exactly between primary and standby clusters after backup/restore operations.

Run:

```bash
make test-e2e-walg
```

or

```bash
cd e2e-tests
make test-e2e-walg
```

or manually:

```bash
cd [docker-greenplum-root]/e2e-tests
docker compose -f docker-compose.s3.yml -f docker-compose.gpdb.yml -f docker-compose.gpdb-restore.yml up -d
GREENPLUM_PASSWORD=$(cat ../docker-compose/secrets/gpdb_password) GP_VERSION=$(grep '^CONFIG_FOLDER=' .env | head -1 | cut -d'=' -f2 | tr -d '"') ./scripts/e2e-test.sh
docker compose -f docker-compose.s3.yml -f docker-compose.gpdb.yml -f docker-compose.gpdb-restore.yml down
```

### Yezzey tests

Cluster is described in `e2e-tests/docker-compose.yezzey.yml`, and S3 compatible storage is reused from `e2e-tests/docker-compose.s3.yml`.

The test validates Yezzey data offloading functionality for OpenGPDB. Test tables are created during cluster initialization via [yezzey_init.sql](./yezzey/init_scripts/yezzey_init.sql).

1. **AO table test** (`yezzey_test_ao`):
   - Offloads table data to S3 using `yezzey_define_offload_policy()`
   - Verifies data is still accessible after offload
   - Performs DELETE and VACUUM operations on offloaded table
   - Loads data back to local storage using `yezzey_load_relation()`
   - Re-offloads and runs VACUUM (YEZZEY) for S3 cleanup

2. **AOCS table test** (`yezzey_test_aocs`):
   - Same set of operations for column-oriented table

**Note:** Yezzey tests are only supported for open-gpdb image.

For more details about Yezzey and Yproxy, see [Yezzey and Yproxy documentation](../docs/yezzey_yproxy.md).

Run:

```bash
make test-e2e-yezzey
```

or

```bash
cd e2e-tests
make test-e2e-yezzey
```

or manually:

```bash
cd [docker-greenplum-root]/e2e-tests
```bash
cd e2e-tests
docker compose -f docker-compose.s3.yml -f docker-compose.yezzey.yml up -d
GREENPLUM_PASSWORD=$(cat ../docker-compose/secrets/gpdb_password) ./scripts/e2e-yezzey-test.sh
docker compose -f docker-compose.s3.yml -f docker-compose.yezzey.yml down
```
