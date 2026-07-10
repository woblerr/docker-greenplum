#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/common.sh"

GP_STANDBY_PORT=${EXPOSE_MASTER_STANDBY_PORT:-6432}
MASTER_DATA_DIRECTORY_EXPR='${COORDINATOR_DATA_DIRECTORY:-${MASTER_DATA_DIRECTORY}}'

PRIMARY_MASTER_CONTAINER="master"
STANDBY_MASTER_CONTAINER="standby"

verify_standby_replication() {
    local port=$1
    echo "INFO - Verifying standby replication state"
    local sync_state
    sync_state=$(exec_sql ${port} "SELECT state FROM pg_stat_replication ORDER BY CASE WHEN application_name LIKE '%walreceiver%' THEN 0 ELSE 1 END LIMIT 1;" | xargs)
    if [ "${sync_state}" == "streaming" ] || [ "${sync_state}" == "catchup" ]; then
        echo "INFO - Standby is successfully replicating in state: ${sync_state}"
    else
        echo "ERROR - Standby replication state is unexpected: '${sync_state}' (expected streaming or catchup)"
        exit 1
    fi
}

echo "INFO - Check primary Greenplum cluster"
sleep 90
echo "INFO - Waiting cluster startup on port ${GP_MASTER_PORT}"
wait_for_service ${GP_MASTER_PORT}

echo "INFO - Inserting test data on primary master"
exec_sql ${GP_MASTER_PORT} "CREATE TABLE standby_test (id int); INSERT INTO standby_test VALUES (1), (2), (3);"
RECORD_COUNT=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM standby_test;" | xargs)
echo "INFO - Found ${RECORD_COUNT} records via primary master"

# Test with correctly stopping the primary master first.
# Should use gpactivatestandby with -f to force promotion of standby master.
echo "INFO - Stopping the primary master"
exec_docker ${PRIMARY_MASTER_CONTAINER} "gpstop -M fast -a"
echo "INFO - Activating standby master"
# Catch rc=2 due to Cloudberry issue https://github.com/apache/cloudberry/issues/1717
set +e
exec_docker ${STANDBY_MASTER_CONTAINER} "PGPORT=5432 gpactivatestandby -d ${MASTER_DATA_DIRECTORY_EXPR} -a -f"
rc=$?
if [ $rc -eq 2 ]; then
    echo 'WARNING - Bypassing Cloudberry issue 1717...'
    sleep 15
    echo "INFO - Restarting promoted master to bypass Cloudberry issue 1717"
    exec_docker ${STANDBY_MASTER_CONTAINER} "gpstop -ar"
elif [ $rc -ne 0 ]; then
    exit $rc
fi
set -e
# End catch issue.
echo "INFO - Waiting for activated standby to become ready"
wait_for_service ${GP_STANDBY_PORT}
echo "INFO - Checking if test data is available on the newly promoted master"
STANDBY_RECORD_COUNT=$(exec_sql ${GP_STANDBY_PORT} "SELECT COUNT(*) FROM standby_test;" | xargs)
echo "INFO - Found ${STANDBY_RECORD_COUNT} records via promoted standby master"
if [ "${RECORD_COUNT}" != "${STANDBY_RECORD_COUNT}" ]; then
    echo "ERROR - Data mismatch! Primary had ${RECORD_COUNT} but new master has ${STANDBY_RECORD_COUNT} records."
    exit 1
fi
echo "INFO - Cleaning data directory on the old primary master"
exec_docker ${PRIMARY_MASTER_CONTAINER} "rm -rf ${MASTER_DATA_DIRECTORY_EXPR}"
echo "INFO - Initializing old master as new standby from current primary"
exec_docker ${STANDBY_MASTER_CONTAINER} "gpinitstandby -s master -a"
sleep 15
verify_standby_replication ${GP_STANDBY_PORT}

# Test with downing the primary master without gpstop (simulating a crash).
echo "INFO - Simulating crash on current primary master (standby container)"
docker kill ${STANDBY_MASTER_CONTAINER}
echo "INFO - Activating standby master (on original master) without -f"
exec_docker ${PRIMARY_MASTER_CONTAINER} "PGPORT=5432 gpactivatestandby -d ${MASTER_DATA_DIRECTORY_EXPR} -a"
echo "INFO - Waiting for activated standby to become ready"
wait_for_service ${GP_MASTER_PORT}
echo "INFO - Checking if test data is available on the newly promoted master"
RESTORED_RECORD_COUNT=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM standby_test;" | xargs)
echo "INFO - Found ${RESTORED_RECORD_COUNT} records via promoted standby master (original master)"
if [ "${RECORD_COUNT}" != "${RESTORED_RECORD_COUNT}" ]; then
    echo "ERROR - Data mismatch! Primary had ${RECORD_COUNT} but new master has ${RESTORED_RECORD_COUNT} records."
    exit 1
fi
echo "INFO - Reviving the crashed container"
docker start ${STANDBY_MASTER_CONTAINER}
echo "INFO - Waiting for sshd to start"
sleep 15
echo "INFO - Cleaning data directory on the old crashed primary"
exec_docker ${STANDBY_MASTER_CONTAINER} "rm -rf ${MASTER_DATA_DIRECTORY_EXPR}"
echo "INFO - Initializing crashed node as new standby from current primary"
exec_docker ${PRIMARY_MASTER_CONTAINER} "gpinitstandby -s standby -a"
sleep 15
verify_standby_replication ${GP_MASTER_PORT}

echo "INFO - Standby master test completed successfully"
