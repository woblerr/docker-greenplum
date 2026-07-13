#!/usr/bin/env bash
set -Eeuo pipefail

GP_USER=${GREENPLUM_USER:-gpadmin}
GP_PASSWORD=${GREENPLUM_PASSWORD:-}
GP_MASTER_PORT=${EXPOSE_MASTER_PORT:-5432}
GP_DB_NAME=${GREENPLUM_DATABASE_NAME:-demo}

# Check password is set
if [ -z "$GP_PASSWORD" ]; then
    echo "ERROR - GREENPLUM_PASSWORD variable is not set"
    exit 1
fi

exec_sql() {
    local port=$1
    local sql=$2
    PGPASSWORD=${GP_PASSWORD} psql -h localhost -U ${GP_USER} -d ${GP_DB_NAME} -p ${port} -t -c "${sql}"
}

exec_docker(){
    local container=$1
    local cmd=$2
    docker exec ${container} su - ${GP_USER} -c "${cmd}"
}

wait_for_service() {
    local port=$1
    local max_attempts=${2:-10}

    for i in $(seq 1 ${max_attempts}); do
        if exec_sql ${port} "SELECT 1;" >/dev/null 2>&1; then
            echo "INFO - Cluster ready on port ${port}"
            return 0
        fi
        echo "INFO - Waiting cluster startup on port ${port} ($i/${max_attempts})"
        sleep 10
    done
    echo "ERROR - Cluster failed to start within timeout"
    return 1
}
