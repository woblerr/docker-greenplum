# AGENTS.md

## Project Overview

This repository builds Docker images for Greenplum-compatible databases: Greenplum, Greengage, WarehousePG, and open-gpdb. The runtime entrypoint is `docker/files/entrypoint.sh`; normal images use `docker/files/start_gpdb.sh`, while open-gpdb uses `docker/files/opengpdb/start_gpdb.sh` for Yezzey/Yproxy support.

## Project Structure

- `docker/<image>/<os>/<major>/Dockerfile`: image build definitions.
- `docker/files/`: shared container entrypoint and startup scripts.
- `docker-compose/`: example clusters, compose `.env`, configs, and ignored local password files under `docker-compose/secrets/`.
- `e2e-tests/`: Docker Compose e2e stacks, test Makefile, shell test scripts, WAL-G and Yezzey fixtures.
- `docs/yezzey_yproxy.md`: open-gpdb Yezzey/Yproxy user documentation.

## Build, Test, and Lint

Use the root `Makefile` for builds. Verified build targets include:

```bash
make build_gpdb_6_ubuntu TAG_GPDB_6=6.27.1
make build_gpdb_7_ubuntu TAG_GPDB_7=7.1.0
make build_greengage_6_ubuntu TAG_GREENGAGE_6=6.31.0
make build_greengage_7_ubuntu TAG_GREENGAGE_7=7.5.0
make build_warehousepg_6_ubuntu TAG_WAREHOUSEPG_6=6.27.5-WHPG
make build_warehousepg_7_ubuntu TAG_WAREHOUSEPG_7=7.4.1-WHPG
make build_opengpdb_6_ubuntu TAG_OPENGPDB_6=6.29.8
```

For Greenplum, Greengage, and WarehousePG, matching Oracle Linux targets exist with `_oraclelinux` instead of `_ubuntu`. open-gpdb has only `build_opengpdb_6_ubuntu`.

No lint or format target is currently defined in the repo.

## End-to-End Tests

E2E tests require Docker Compose, locally built images that match `e2e-tests/.env`, and password files in `docker-compose/secrets/`.

```bash
make test-e2e
make test-e2e-walg
make test-e2e-standby-master
make test-e2e-yezzey
```

`make test-e2e` runs the WAL-G and standby-master suites only.
Run `make test-e2e-yezzey` separately for the open-gpdb-only Yezzey suite.

Ask before running e2e targets. They start and stop Docker Compose clusters, use MinIO/nginx for S3-compatible storage, and some scripts clean `/data` directories inside test containers or kill/restart containers.

Do not dry-run e2e Makefile targets when secret output matters: `e2e-tests/Makefile` reads `../docker-compose/secrets/gpdb_password` while expanding commands.

## Runtime and Safety Rules

- Do not commit local password files. `.gitignore` ignores `docker-compose/secrets/*` and `docker-compose/.secrets/*`, except `docker-compose/secrets/.gitkeep`.
- Docker Compose examples mount Greenplum config files into `/tmp` and SSH files into the container user home; keep those paths aligned with `README.md` and the startup scripts.
- `GREENPLUM_DEPLOYMENT` supports `singlenode`, `master`, `segment`, and `standby`; segment commands expect arguments like `00:primary`.
- Yezzey/Yproxy is open-gpdb-only. Changes to `GREENPLUM_YEZZEY_ENABLE`, `yproxy.yaml`, or Yezzey tests must stay consistent with `docker/files/opengpdb/start_gpdb.sh`, `docs/yezzey_yproxy.md`, and `e2e-tests/docker-compose.yezzey.yml`.
- GitHub Actions push images and manifest lists only for tag pushes matching `refs/tags/v*`; do not add local push commands unless explicitly requested.

## Keep In Sync

Keep the following surfaces synchronized according to the type of change:

- For image versions, build arguments, or supported OS/major versions, update `Makefile`, relevant Dockerfiles, the `README.md` build matrix and examples, `docker-compose/.env`, `e2e-tests/.env`, and matching `.github/workflows/build-*.yml` matrices.
- For shared Greenplum startup behavior, keep `docker/files/start_gpdb.sh` and `docker/files/opengpdb/start_gpdb.sh` aligned unless the behavior is intentionally image-specific.
- For runtime environment variables, update their Dockerfile defaults, the applicable startup scripts, the `README.md` variable list and examples, Docker Compose configurations, and relevant e2e fixtures and coverage.
- For e2e targets or behavior, update the root and `e2e-tests` Makefiles, matching shell scripts and Docker Compose files, and `e2e-tests/README.md`.
- For custom initialization behavior, keep both startup scripts, the `README.md` initialization documentation, and fixtures under `docs/custom_init_scripts/` aligned.
- For open-gpdb Yezzey/Yproxy behavior, keep `docker/files/opengpdb/start_gpdb.sh`, `docs/yezzey_yproxy.md`, `e2e-tests/docker-compose.yezzey.yml`, and the Yezzey fixtures and tests synchronized.
- When adding or moving shared files used by image builds, update the `files_yaml` change filters in every affected `.github/workflows/build-*.yml` workflow.

## Verification

For Makefile or Dockerfile changes, inspect the relevant build routing with `make -n`, for example:

```bash
make -n build_gpdb_6_ubuntu TAG_GPDB_6=6.27.1
```

A dry run validates command expansion only; it does not prove that the image builds successfully.
Build the affected image when practical, and report explicitly when the real build was not run.

For startup or runtime changes, run the relevant e2e suite only after explicit approval.
Never use `make -n` with e2e targets: `e2e-tests/Makefile` reads the local Greenplum password at parse time and may expose it in expanded commands.

For documentation-only changes, do not run image builds or code tests unless needed to validate a documented command.

Always run `git diff --check` before handing off changes.
