# End-to-end tests

The following architecture is used to run the tests:

* Separate containers with Greenplum (GPDB, Greengage, WarehousePG, or open-gpdb).
* Separate containers for MinIO and nginx. Official images [minio/minio](https://hub.docker.com/r/minio/minio), [minio/mc](https://hub.docker.com/r/minio/mc) and [nginx](https://hub.docker.com/_/nginx) are used. It's necessary for S3 compatible storage for WAL archiving and backups.

## Prerequisites

Before running tests:

1. Build Greenplum docker images as described in [Build section](../README.md#build).

2. Configure test environment by editing `e2e-tests/.env` file if needed (default: `GPDB 6.27.1`, other supported: `Greengage`, `WarehousePG`, `open-gpdb`).

3. Prepare password files as described in [Prepare section](../README.md#prepare) for Docker Compose. The tests use SSH keys from the `../docker-compose/conf/ssh/` directory, so you can use them or create your own.

## Running tests

Run all tests:
```bash
make test-e2e
``` 

### Greengage 6 validation

Validate Greengage 6.32.0 on Ubuntu 22.04 and Oracle Linux 8, on both `linux/amd64` and `linux/arm64`. Successful image builds do not establish runtime compatibility. Use disposable clusters for these checks: the existing suites stop containers, simulate crashes, and remove test data directories.

The following commands run the existing WAL-G and standby master suites from the repository root against locally available images. Both example `.env` files select Greenplum by default, so override the image and configuration explicitly:

```bash
export IMAGE_NAME=greengage
export TAG=6.32.0-ubuntu22.04
export RESTORE_TAG=6.32.0-ubuntu22.04
export CONFIG_FOLDER=6
export RESTORE_CONFIG_FOLDER=6
make test-e2e CONFIG_FOLDER=6
```

For Oracle Linux, set both `TAG` and `RESTORE_TAG` to `6.32.0-oraclelinux8` and repeat on each architecture. The Make argument `CONFIG_FOLDER=6` also overrides the value that the test Makefile reads directly from `.env`. Do not use `make -n` with e2e targets: the test Makefile reads the password file while expanding commands.

The existing suites cover WAL-G backup/PITR and standby promotion. Complete the following additional checks separately:

1. **Startup and extensions.** Initialize single-node and multi-node clusters, restart with existing `/data`, and verify custom initialization scripts run only on a new cluster. Check the `greenplum_path.sh` symlink, Python module imports, and binary versions. With the corresponding features enabled, verify gpperfmon metrics, diskquota accounting and quota enforcement, PXF external-table reads/writes, and `gp_pitr`. Confirm that `credcheck` and `pg_cron` are installed; they do not need to be enabled by default.
2. **Authentication.** Check successful and rejected password authentication over TCP using a connection that matches an MD5 rule rather than `trust`. Test SCRAM and deployed client versions; include LDAP/PAM/Kerberos/RADIUS where configured. CVE-2026-6478 verification should include the upstream [constant-time comparison fix](https://github.com/GreengageDB/greengage/pull/606) in the source used for the build, rather than relying on response-time measurements.
3. **credcheck.** Enable `credcheck` through `shared_preload_libraries` on a disposable cluster and exercise the [6.32.0 regression cases](https://github.com/GreengageDB/greengage/tree/6.32.0/gpcontrib/credcheck/test/sql). With `credcheck.password_valid_until` enabled, a non-superuser must be able to change its own password but must not gain `SUPERUSER`, `CREATEROLE`, or `CREATEDB`. Reject password-policy violations in multi-statement queries and `DO` blocks. Deny ordinary roles access to both the password-history view and function, while allowing superuser access. Set the same password for two test roles and verify different history hashes. Verify new history survives restart and standby promotion.
4. **Backup consumers.** Run gpbackup/gprestore with local storage and the S3 plugin for heap, AO/AOCS, and partitioned tables, roles, and extensions. Check gpbackman reads the resulting `gpbackup_history.db`; if gpbackup_exporter is deployed, verify its status and backup metrics against that history.
5. **Existing data.** On a copy of a 6.31.0 cluster, prepare representative data, roles, extensions, and an enabled `credcheck` history. Stop all nodes and upgrade to 6.32.0 using the [upgrade procedure](../README.md#upgrading-greengage-6). Check data and privileges, the expected reset of old history, creation of new history, and stale history files on segments and mirrors. Also restore a WAL-G backup made by 6.31.0 into a separate 6.32.0 cluster.
6. **Standby and rollback.** Require `gpactivatestandby` to return `0`; a run that takes the existing Cloudberry exit-code-2 workaround is not a successful Greengage validation. Check consumers of `gpstate -e` and `EXPLAIN ANALYZE` output. Rehearse restoring the saved cluster backup with the old image digests and verify data, roles, authentication, and backup operations.

Record the source revision, image digests, OS/architecture, and results for each check. Treat failed authentication, extension loading, backup/restore, promotion, or data comparisons as blockers. Confirm acceptance of the password-history reset before upgrading a cluster that relies on it. Yezzey tests apply only to open-gpdb.

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

### Standby master tests

The cluster is described in `../docker-compose/docker-compose.with_mirrors_and_standby.yaml`.

The test validates standby master promotion and cluster recovery functionality:

1. **Graceful failover test**:
   - Stops the primary master gracefully
   - Promotes the standby master to be the new primary
   - Compares test data on the new primary
   - Cleans up and initializes the old primary as a new standby master
   - Verifies the standby replication state

2. **Crash recovery test**:
   - Simulates a crash by killing the primary master container
   - Promotes the standby master
   - Compares test data on the new primary
   - Revives the crashed container, cleans up data, and re-initializes it as a standby
   - Verifies the standby replication state

Run:

```bash
make test-e2e-standby-master
```

or

```bash
cd e2e-tests
make test-e2e-standby-master
```

or manually:

```bash
cd [docker-greenplum-root]/e2e-tests
docker compose -f ../docker-compose/docker-compose.with_mirrors_and_standby.yaml up -d
GREENPLUM_PASSWORD=$(cat ../docker-compose/secrets/gpdb_password) ./scripts/e2e-standby-master-test.sh
docker compose -f ../docker-compose/docker-compose.with_mirrors_and_standby.yaml down
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
