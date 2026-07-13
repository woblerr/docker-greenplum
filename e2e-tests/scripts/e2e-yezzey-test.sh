#!/usr/bin/env bash
set -Eeuo pipefail

GP_USER=${GREENPLUM_USER:-gpadmin}
GP_PASSWORD=${GREENPLUM_PASSWORD:-}
GP_MASTER_PORT=${EXPOSE_MASTER_PORT:-5432}
GP_DB_NAME=${GREENPLUM_DATABASE_NAME:-demo}

MASTER_CONTAINER="master"
YPROXY_SOCKET="/tmp/yproxy.sock"
YPROXY_LOG="/data/yproxy.log"

# Check password is set
if [ -z "$GP_PASSWORD" ]; then
    echo "ERROR - GP_PASSWORD variable is not set"
    exit 1
fi

exec_sql() {
    local port=$1
    local sql=$2
    PGPASSWORD=${GP_PASSWORD} psql -h localhost -U ${GP_USER} -d ${GP_DB_NAME} -p ${port} -t -c "${sql}"
}

exec_docker() {
    local container_name=$1
    local cmd=$2
    docker exec ${container_name} su - ${GP_USER} -c "${cmd}"
}

wait_for_service() {
    local port=$1
    local max_attempts=${2:-10}

    for i in $(seq 1 ${max_attempts}); do
        if exec_sql ${port} "SELECT 1;" >/dev/null 2>&1; then
            echo "INFO - Cluster ready"
            return 0
        fi
        echo "INFO - Waiting cluster startup ($i/${max_attempts})"
        sleep 10
    done
    echo "ERROR - Cluster failed to start within timeout"
    return 1
}

compare_data() {
    local primary_data=$1
    local standby_data=$2

    echo "INFO - Row count first argument:"
    echo "$primary_data"
    echo "INFO - Row count second argument:"
    echo "$standby_data"

    if [ "$primary_data" = "$standby_data" ]; then
        echo "INFO - Data matches"
    else
        echo "ERROR - Data mismatch"
        exit 1
    fi
}

echo "INFO - Check Greenplum cluster"
sleep 90
echo "INFO - Waiting cluster startup"
wait_for_service ${GP_MASTER_PORT}

# Test AO table
echo "INFO - Test AO (Append-Optimized) table"
echo "INFO - Check row count before offload"
row_count_before=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_ao;")
echo "INFO - Row count before offload: $row_count_before"

echo "INFO - Offload AO table to S3"
exec_sql ${GP_MASTER_PORT} "SELECT yezzey_define_offload_policy('yezzey_test_ao');"
echo "INFO - Check row count after offload"
row_count_after=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_ao;")
echo "INFO - Row count after offload: $row_count_after (data accessible from S3)"

compare_data "$row_count_before" "$row_count_after"

echo "INFO - Test DELETE after offload"
exec_sql ${GP_MASTER_PORT} "DELETE FROM yezzey_test_ao where id <= 5000;"
row_count_after_delete=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_ao;")
echo "INFO - Row count after DELETE: $row_count_after_delete"

echo "INFO - Run VACUUM on AO table"
exec_sql ${GP_MASTER_PORT} "VACUUM yezzey_test_ao;"
row_count_after_vacuum=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_ao;")
echo "INFO - Row count after VACUUM: $row_count_after_vacuum (no dead tuples)"

compare_data "$row_count_after_delete" "$row_count_after_vacuum"

echo "INFO - Load AO table back to local storage"
exec_sql ${GP_MASTER_PORT} "SELECT yezzey_load_relation('yezzey_test_ao');"
row_count_after_load=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_ao;")
echo "INFO - Row count after load from S3: $row_count_after_load"

echo "INFO - Offload AO table to S3 again"
exec_sql ${GP_MASTER_PORT} "SELECT yezzey_define_offload_policy('yezzey_test_ao');"
echo "INFO - Run VACUUM (YEZZEY) on AO table"
exec_sql ${GP_MASTER_PORT} "VACUUM (YEZZEY) yezzey_test_ao;"
row_count_final=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_ao;" )
echo "INFO - Final AO row count: $row_count_final"

compare_data "$row_count_after_load" "$row_count_final"

# Test AOCO table
echo "INFO - Test AOCO (Column-Oriented) table"
echo "INFO - Create AOCO table"
echo "INFO - Check row count before offload"
row_count_aocs_before=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_aocs;")
echo "INFO - Row count before offload: $row_count_aocs_before"

echo "INFO - Offload AOCO table to S3"
exec_sql ${GP_MASTER_PORT} "SELECT yezzey_define_offload_policy('yezzey_test_aocs');"
echo "INFO - Check row count after offload"
row_count_aocs_after=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_aocs;")
echo "INFO - Row count after offload: $row_count_aocs_after (data accessible from S3)"

compare_data "$row_count_aocs_before" "$row_count_aocs_after"

echo "INFO - Test DELETE after offload"
exec_sql ${GP_MASTER_PORT} "DELETE FROM yezzey_test_aocs WHERE id <= 5000;"
row_count_aocs_after_delete=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_aocs;")
echo "INFO - Row count after DELETE: $row_count_aocs_after_delete"

echo "INFO - Run VACUUM on AOCO table"
exec_sql ${GP_MASTER_PORT} "VACUUM yezzey_test_aocs;"
row_count_aocs_after_vacuum=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_aocs;")
echo "INFO - Row count after VACUUM: $row_count_aocs_after_vacuum (no dead tuples)"

compare_data "$row_count_aocs_after_delete" "$row_count_aocs_after_vacuum"

echo "INFO - Load AOCO table back to local storage"
exec_sql ${GP_MASTER_PORT} "SELECT yezzey_load_relation('yezzey_test_aocs');"
row_count_aocs_after_load=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_aocs;")
echo "INFO - Row count after load from S3: $row_count_aocs_after_load"

echo "INFO - Offload AOCO table to S3 again"
exec_sql ${GP_MASTER_PORT} "SELECT yezzey_define_offload_policy('yezzey_test_aocs');"
echo "INFO - Run VACUUM (YEZZEY) on AOCO table"
exec_sql ${GP_MASTER_PORT} "VACUUM (YEZZEY) yezzey_test_aocs;"
row_count_aocs_final=$(exec_sql ${GP_MASTER_PORT} "SELECT COUNT(*) FROM yezzey_test_aocs;")
echo "INFO - Final AOCO row count: $row_count_aocs_final"

compare_data "$row_count_aocs_after_load" "$row_count_aocs_final"

echo "INFO - Yezzey E2E tests completed successfully"
