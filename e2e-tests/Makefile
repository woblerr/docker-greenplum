GPDB_PASSWORD := $(shell cat ../docker-compose/secrets/gpdb_password)
CONFIG_FOLDER := $(shell grep '^CONFIG_FOLDER=' .env | head -1 | cut -d'=' -f2 | tr -d '"')

.PHONY: test-e2e
test-e2e: test-e2e-walg test-e2e-standby-master

.PHONY: test-e2e-standby-master
test-e2e-standby-master:
	make test-e2e-standby-master-down
	make test-e2e-standby-master-up
	make test-e2e-standby-master-run
	make test-e2e-standby-master-down

.PHONY: test-e2e-standby-master-up
test-e2e-standby-master-up:
	@echo "INFO - Start e2e tests for standby master"
	docker compose -f ../docker-compose/docker-compose.with_mirrors_and_standby.yaml up -d

.PHONY: test-e2e-standby-master-run
test-e2e-standby-master-run:
	@echo "INFO - Run e2e tests for standby master"
	GREENPLUM_PASSWORD=$(GPDB_PASSWORD) ./scripts/e2e-standby-master-test.sh

.PHONY: test-e2e-standby-master-down
test-e2e-standby-master-down:
	@echo "INFO - Stop e2e tests for standby master"
	docker compose -f ../docker-compose/docker-compose.with_mirrors_and_standby.yaml down

.PHONY: test-e2e-walg
test-e2e-walg: 
	make test-e2e-walg-down
	make test-e2e-walg-up
	make test-e2e-walg-run 
	make test-e2e-walg-down

.PHONY: test-e2e-walg-up
test-e2e-walg-up:
	@echo "INFO - Start e2e tests for wal-g"
	docker compose -f docker-compose.s3.yml -f docker-compose.gpdb.yml -f docker-compose.gpdb-restore.yml up -d

.PHONY: test-e2e-walg-run
test-e2e-walg-run:
	@echo "INFO - Run e2e tests for wal-g"
	GREENPLUM_PASSWORD=$(GPDB_PASSWORD) GP_VERSION=$(CONFIG_FOLDER) ./scripts/e2e-test.sh

.PHONY: test-e2e-walg-down
test-e2e-walg-down:
	@echo "INFO - Stop e2e tests for wal-g"
	docker compose -f docker-compose.s3.yml -f docker-compose.gpdb.yml -f docker-compose.gpdb-restore.yml down

.PHONY: test-e2e-yezzey
test-e2e-yezzey:
	make test-e2e-yezzey-down
	make test-e2e-yezzey-up
	make test-e2e-yezzey-run
	make test-e2e-yezzey-down

.PHONY: test-e2e-yezzey-up
test-e2e-yezzey-up:
	@echo "INFO - Start e2e tests for Yezzey"
	docker compose -f docker-compose.s3.yml -f docker-compose.yezzey.yml up -d

.PHONY: test-e2e-yezzey-run
test-e2e-yezzey-run:
	@echo "INFO - Run e2e tests for Yezzey"
	GREENPLUM_PASSWORD=$(GPDB_PASSWORD) ./scripts/e2e-yezzey-test.sh

.PHONY: test-e2e-yezzey-down
test-e2e-yezzey-down:
	@echo "INFO - Stop e2e tests for Yezzey"
	docker compose -f docker-compose.s3.yml -f docker-compose.yezzey.yml down
