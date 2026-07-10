#!/usr/bin/env bash
set -Eeuo pipefail

gp_init_config_file="${GREENPLUM_DATA_DIRECTORY}/gpinitsystem_config"
gp_init_host_file="${GREENPLUM_DATA_DIRECTORY}/hostfile_gpinitsystem"
gp_custom_init_dir="/docker-entrypoint-initdb.d"
gp_master_dir_name="master"
gp_hostname=$(hostname)

error_and_exit() {
    echo "ERROR - $1"
    exit 1
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        error_and_exit "Both $var and $fileVar are set (but are exclusive)"
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

setup_version_config() {
    source "/home/${GREENPLUM_USER}/.bashrc"
    # Get gpdb major version from gpinitsystem command.
    # It's necessary to know the version to operate with the correct directories.
    # Example: gpinitsystem 6.26.4 build dev
    gp_version_string=$(gpinitsystem --version)
    gp_major_version=""
    if [[ "${gp_version_string}" =~ ([0-9]+)[.][0-9]+[.][0-9]+ ]]; then
        gp_major_version="${BASH_REMATCH[1]}"
    fi
    case "${gp_major_version}" in
      "6")
        gp_log_dir="pg_log"
        gp_master_data_dir_prefix="MASTER"
        ;;
      "7")
        gp_log_dir="log"
        gp_master_data_dir_prefix="COORDINATOR"
        ;;
      *)
        error_and_exit "Invalid Greenplum version from gpinitsystem output: ${gp_version_string}"
        ;;
    esac
}

create_directory() {
    local dir=$1
    if [ ! -d "${dir}" ]; then
        echo "INFO - Creating directory: ${dir}"
        mkdir -p "${dir}"
    fi
}

setup_master() {
    echo "export ${gp_master_data_dir_prefix}_DATA_DIRECTORY=${GREENPLUM_DATA_DIRECTORY}/${gp_master_dir_name}/${GREENPLUM_SEG_PREFIX}-1" >> ~/.bashrc
    source "/home/${GREENPLUM_USER}/.bashrc"
    create_directory "${GREENPLUM_DATA_DIRECTORY}/${gp_master_dir_name}"
}

setup_segments() {
    local segment_num=$1
    local segment_type=$2
    create_directory "${GREENPLUM_DATA_DIRECTORY}/${segment_num}/${segment_type}"
}

# Resolve issue for GPDB 7 with mounted authorized_keys in docker
# In GPDB 7, gpssh-exkeys use rsync to copy the authorized_keys
# and we get error:
#   rsync: rename "/home/gpadmin/.ssh/.authorized_keys.wiHHYt" -> "authorized_keys": Device or resource busy (16)
# For GPDB 6 the problem is not reproduced, because the scp command is used.
setup_segment_authorized_keys(){
    if [ -f /tmp/authorized_keys ]; then
        echo "INFO - Copy authorized_keys to /home/${GREENPLUM_USER}/.ssh/authorized_keys"
        cp /tmp/authorized_keys /home/${GREENPLUM_USER}/.ssh/authorized_keys
        chmod 600 /home/${GREENPLUM_USER}/.ssh/authorized_keys
    fi
}

verify_prerequisites() {
    file_env "GREENPLUM_PASSWORD"

    check_required_var "GREENPLUM_DATA_DIRECTORY" "${GREENPLUM_DATA_DIRECTORY}"
    check_required_var "GREENPLUM_PASSWORD" "${GREENPLUM_PASSWORD}"
    # Check gpperfmon password only if gpperfmon is enabled for GPDB6 master deployment
    if is_gpperfmon_enabled; then
        file_env "GREENPLUM_GPMON_PASSWORD"
        check_required_var "GREENPLUM_GPMON_PASSWORD" "${GREENPLUM_GPMON_PASSWORD}"
    fi
}

is_gpperfmon_enabled() {
    [[ "${GREENPLUM_GPPERFMON_ENABLE}" == "true" && 
       "${gp_major_version}" == "6" && 
       "${GREENPLUM_DEPLOYMENT}" == "master" ]]
}

check_required_var() {
    local var_name=$1
    local var_value=$2
    if [ -z "${var_value}" ]; then
        error_and_exit "${var_name} variable is not set!"
    fi
}

setup_gpinitsystem_config(){
    if [ -f /tmp/gpinitsystem_config ]; then
        echo "INFO - Copy gpinitsystem_config to ${gp_init_config_file}"
        cp /tmp/gpinitsystem_config "${gp_init_config_file}"
    fi
}

generate_gpinitsystem_config() {
    if [ ! -f "${gp_init_config_file}" ] ; then
        cat > "${gp_init_config_file}" <<EOF
ARRAY_NAME="Greenplum in docker"
DATABASE_NAME=${GREENPLUM_DATABASE_NAME}
SEG_PREFIX=${GREENPLUM_SEG_PREFIX}
PORT_BASE=6000
${gp_master_data_dir_prefix}_HOSTNAME=${gp_hostname}
${gp_master_data_dir_prefix}_DIRECTORY=${GREENPLUM_DATA_DIRECTORY}/${gp_master_dir_name}
${gp_master_data_dir_prefix}_PORT=5432
TRUSTED_SHELL=ssh
CHECK_POINT_SEGMENTS=8
ENCODING=UNICODE
MACHINE_LIST_FILE=${gp_init_host_file}
declare -a DATA_DIRECTORY=(${GREENPLUM_DATA_DIRECTORY}/00/primary ${GREENPLUM_DATA_DIRECTORY}/01/primary)
EOF
    fi
}

setup_hostfile_gpinitsystem(){
    if [ -f /tmp/hostfile_gpinitsystem ]; then
        echo "INFO - Copy hostfile_gpinitsystem to ${gp_init_host_file}"
        cp /tmp/hostfile_gpinitsystem "${gp_init_host_file}"
    fi
}

generate_hostfile_gpinitsystem() {
    if [ ! -f "${gp_init_host_file}" ] ; then
        echo "${gp_hostname}" > ${gp_init_host_file}
    fi
}

check_hostfile_gpinitsystem() {
    if [ ! -f "${gp_init_host_file}" ]; then
        error_and_exit "Hostfile ${gp_init_host_file} is required but not found. Please mount hostfile_gpinitsystem."
    fi
}

execute_custom_init_scripts() {
    local script
    if [ -d "${gp_custom_init_dir}" ] && [ -n "$(ls -A ${gp_custom_init_dir})" ]; then
        echo "INFO - Executing custom initialization scripts"
        for script in "${gp_custom_init_dir}"/*; do
            case "${script}" in
                *.sh)
                    if [ -x "${script}" ]; then
                        echo "INFO - Executing shell script: ${script}"
                        "${script}"
                    else
                        echo "INFO - Sourcing shell script: ${script}"
                        source "${script}"
                    fi
                    ;;
                *.sql)
                    echo "INFO - Executing SQL script: ${script}"
                    psql -v ON_ERROR_STOP=1  --no-psqlrc -U "${GREENPLUM_USER}" -d "${GREENPLUM_DATABASE_NAME}" -f "${script}"
                    ;;
                *)
                    echo "INFO - Ignoring: ${script}"
                    ;;
            esac
        done
        echo "INFO - Finished executing custom initialization scripts"
    fi
}

initialize_and_start_gpdb_segments() {
    local end_flag=""
    local arg segment_num segment_type
    echo "INFO - Initializing segment host"
    if [ $# -eq 0 ]; then
        error_and_exit "No segment specifications provided"
    fi
    for arg in "$@"; do
        if [[ ! "$arg" =~ ^[0-9]+:(primary|mirror)$ ]]; then
            error_and_exit "Invalid segment specification format: $arg, expected format: NUMBER:TYPE"
        fi
        IFS=':' read -r segment_num segment_type <<< "$arg"
        setup_segments "${segment_num}" "${segment_type}"
    done
    trap "echo 'INFO - Shutdown segment host' && end_flag=1" TERM INT
    # Keep container running
    while [ "${end_flag}" == '' ]; do
        sleep 1
    done
}

initialize_and_start_gpdb_standby() {
    local end_flag=""
    echo "INFO - Initializing standby master host"
    for host in $(cat ${gp_init_host_file}); do
        ssh-keyscan -t rsa $host >> /home/${GREENPLUM_USER}/.ssh/known_hosts 2>/dev/null
    done
    if [ -n "${GREENPLUM_MASTER_HOSTNAME:-}" ]; then
        ssh-keyscan -t rsa "${GREENPLUM_MASTER_HOSTNAME}" >> /home/${GREENPLUM_USER}/.ssh/known_hosts 2>/dev/null
    else
        echo "WARNING - GREENPLUM_MASTER_HOSTNAME is not set, skipping ssh-keyscan for master/coordinator"
    fi
    chmod 644 /home/${GREENPLUM_USER}/.ssh/known_hosts
    trap "echo 'INFO - Shutdown standby master host' && end_flag=1" TERM INT
    # Keep container running
    while [ "${end_flag}" == '' ]; do
        sleep 1
    done
}

initialize_and_start_gpdb() {
    local pg_hba="${GREENPLUM_DATA_DIRECTORY}/${gp_master_dir_name}/${GREENPLUM_SEG_PREFIX}-1/pg_hba.conf"
    local pxf_env="${PXF_BASE}/conf/pxf-env.sh"
    local end_flag=""
    local gpdb_already_exists_flag=false

    # Scan and add host keys
    for host in $(cat ${gp_init_host_file}); do
        ssh-keyscan -t rsa $host >> /home/${GREENPLUM_USER}/.ssh/known_hosts 2>/dev/null
    done
    if [ -n "${GREENPLUM_STANDBY_HOSTNAME:-}" ]; then
        ssh-keyscan -t rsa "${GREENPLUM_STANDBY_HOSTNAME}" >> /home/${GREENPLUM_USER}/.ssh/known_hosts 2>/dev/null
    fi
    chmod 644 /home/${GREENPLUM_USER}/.ssh/known_hosts

    # Fetch rsa ssh keys from hosts
    gpssh-exkeys -f "${gp_init_host_file}"

    if [ -f "${pg_hba}" ]; then
        gpdb_already_exists_flag=true
        # In case when we use persistent volume and data catalog is already exists
        # we need to configure .pgpass file for gpperfmon before starting GPDB
        # Otherwise, we get error:
        # 3rd party error log: Performance Monitor - failed to connect to gpperfmon database: fe_sendauth: no password supplied
        if is_gpperfmon_enabled; then
            echo "*:5432:gpperfmon:gpmon:${GREENPLUM_GPMON_PASSWORD}" > /home/${GREENPLUM_USER}/.pgpass
            chmod 600 /home/${GREENPLUM_USER}/.pgpass
        fi
	    echo 'INFO - Start GPDB'
	    gpstart -a
    else
        # Init gpdb
        echo "INFO - Initialize GPDB"
        if [ "${gp_major_version}" == "6" ]; then
            gpinitsystem -e ${GREENPLUM_PASSWORD} -ac ${gp_init_config_file} --ignore-warnings
        else
            gpinitsystem -e ${GREENPLUM_PASSWORD} -ac ${gp_init_config_file}
        fi
        # Enable gpperfmon
        if is_gpperfmon_enabled; then
            echo "INFO - Enable gpperfmon"
            USER=${GREENPLUM_USER} gpperfmon_install --enable --password "${GREENPLUM_GPMON_PASSWORD}" --port 5432
            # Necessary to correct start gpsmon process. Without this, in some cases, the process is not started
            echo "verbose=1" >> ${GREENPLUM_DATA_DIRECTORY}/${gp_master_dir_name}/${GREENPLUM_SEG_PREFIX}-1/gpperfmon/conf/gpperfmon.conf
            # Configure  gp_interconnect_type  to TCP
            # Without this in docker the error for gpsmon could be raised:
            # "send dummy packet failed, sendto failed: Cannot assign requested address",,,,,,,0,,"ic_udpifc.c",7020,
            echo "INFO -  USER=${GREENPLUM_USER} gpconfig -c gp_interconnect_type -v tcp"
            USER=${GREENPLUM_USER} gpconfig -c gp_interconnect_type -v tcp
        fi
        if [ "${GREENPLUM_DISKQUOTA_ENABLE}" == "true" ]; then
            echo "INFO - Enable diskquota"
            echo "INFO - createdb diskquota"
            createdb "diskquota"
            # Get current shared_preload_libraries value
            echo "INFO - psql template1 -t -c \"SHOW shared_preload_libraries\" | xargs"
            gp_shared_preload_libraries=$(psql template1 -t -c "SHOW shared_preload_libraries" | xargs)
            # Get available diskquota version
            echo "INFO - psql template1 -t -c \"SELECT default_version FROM pg_available_extensions WHERE name = 'diskquota'\" | xargs"
            gp_diskquota_version=$(psql template1 -t -c "SELECT default_version FROM pg_available_extensions WHERE name = 'diskquota'" | xargs)
            # Add diskquota to shared_preload_libraries
            if [ -z "${gp_shared_preload_libraries}" ]; then
                echo "INFO - gpconfig -c shared_preload_libraries -v \"diskquota-${gp_diskquota_version}\""
                USER=${GREENPLUM_USER} gpconfig -c shared_preload_libraries -v "diskquota-${gp_diskquota_version}"
            else
                echo "INFO - gpconfig -c shared_preload_libraries -v \"'$gp_shared_preload_libraries,diskquota-${gp_diskquota_version}'\""
                USER=${GREENPLUM_USER} gpconfig -c shared_preload_libraries -v "'$gp_shared_preload_libraries,diskquota-${gp_diskquota_version}'"
            fi
        fi
        if [ "${GREENPLUM_WALG_ENABLE}" == "true" ]; then
            echo "INFO - Set parameters for WAL archiving"
            echo "INFO - gpconfig -c archive_mode -v on"
            USER=${GREENPLUM_USER} gpconfig -c archive_mode -v on
            echo "INFO - gpconfig -c archive_command -v '/bin/true'"
            # Set archive_command to /bin/true because there is no storage for WAL specified
            # This is necessary to avoid errors
            # Use init script to set actual archive_command
            USER=${GREENPLUM_USER} gpconfig -c archive_command -v "'/bin/true'"
            if [ "${gp_major_version}" == "6" ]; then
                echo "INFO - gpconfig -c wal_level -v archive"
                USER=${GREENPLUM_USER} gpconfig -c wal_level -v archive --skipvalidation
                echo "INFO - psql ${GREENPLUM_DATABASE_NAME} -t -c \"CREATE EXTENSION IF NOT EXISTS gp_pitr;\" | xargs"
                psql ${GREENPLUM_DATABASE_NAME} -t -c "CREATE EXTENSION IF NOT EXISTS gp_pitr;" | xargs
            else
                echo "INFO - gpconfig -c wal_level -v replica"
                USER=${GREENPLUM_USER} gpconfig -c wal_level -v replica --skipvalidation
            fi
        fi
        # Configure pg_hba
        echo "INFO - Configure pg_hba.conf"
        {
            echo "host all all 0.0.0.0/0 md5"
            echo "host all all ::0/0 md5"
        } >> "${pg_hba}"
        echo "INFO - Restart GPDB"
        gpstop -ar
        sleep 10
        if [ -n "${GREENPLUM_STANDBY_HOSTNAME:-}" ]; then
            echo "INFO - Initialize standby master on ${GREENPLUM_STANDBY_HOSTNAME}"
            gpinitstandby -a -s "${GREENPLUM_STANDBY_HOSTNAME}"
        fi
    fi
    # If db name is set and diskquota is enabled, create extension and init table size table
    if [ "${GREENPLUM_DISKQUOTA_ENABLE}" == "true" ] && [ -n "${GREENPLUM_DATABASE_NAME:-}" ]; then
        echo "INFO - psql ${GREENPLUM_DATABASE_NAME} -t -c \"CREATE EXTENSION IF NOT EXISTS diskquota;\" | xargs"
        psql ${GREENPLUM_DATABASE_NAME} -t -c "CREATE EXTENSION IF NOT EXISTS diskquota;" | xargs
        echo "INFO - psql ${GREENPLUM_DATABASE_NAME} -t -c \"SELECT diskquota.init_table_size_table();\" | xargs"
        psql ${GREENPLUM_DATABASE_NAME} -t -c "SELECT diskquota.init_table_size_table();" | xargs
    fi
    # Enable PXF
    if [ ${GREENPLUM_PXF_ENABLE} == "true" ]; then
        if [ ! -f "${pxf_env}" ]; then
            echo "INFO - Enable PXF"
            pxf cluster prepare
            pxf cluster register
            echo "INFO - psql ${GREENPLUM_DATABASE_NAME} -t -c \"CREATE EXTENSION IF NOT EXISTS pxf;\" | xargs"
            psql ${GREENPLUM_DATABASE_NAME} -t -c "CREATE EXTENSION IF NOT EXISTS pxf;" | xargs
            echo "INFO - configure JVM options for PXF"
            # Minimaze JVM memory for PXF.
            # For docker default is too big.
            echo 'PXF_JVM_OPTS="-Xmx512m -Xms256m"' >> ${pxf_env}
            pxf cluster sync
        fi
        echo "INFO - pxf cluster start"
        pxf cluster start
        sleep 10
    fi
    # Monitor logs
    trap "kill %1; \
        if [ ${GREENPLUM_PXF_ENABLE} == 'true' ] && [ -f '${pxf_env}' ]; then \
            echo 'INFO - Stop PXF cluster'; \
            pxf cluster stop; \
        fi; \
        gpstop -a -M fast && end_flag=1" INT TERM
    tail -f $(ls ${GREENPLUM_DATA_DIRECTORY}/${gp_master_dir_name}/${GREENPLUM_SEG_PREFIX}-1/${gp_log_dir}/gpdb-* | tail -n1) &
    # Execute custom init scripts.
    if [ "${gpdb_already_exists_flag}" == false ]; then
        echo "INFO - Execute custom init scripts"
        execute_custom_init_scripts
    fi
    #trap
    while [ "${end_flag}" == '' ]; do
        sleep 1
    done
}

case ${GREENPLUM_DEPLOYMENT} in
    "singlenode")
        setup_version_config
        verify_prerequisites
        setup_master
        setup_segments "00" "primary"
        setup_segments "01" "primary"
        setup_gpinitsystem_config
        generate_gpinitsystem_config
        setup_hostfile_gpinitsystem
        generate_hostfile_gpinitsystem
        initialize_and_start_gpdb
        ;;
    "master")
        setup_version_config
        verify_prerequisites
        setup_master
        setup_gpinitsystem_config
        generate_gpinitsystem_config
        setup_hostfile_gpinitsystem
        check_hostfile_gpinitsystem
        initialize_and_start_gpdb
        ;;
    "segment")
        setup_segment_authorized_keys
        initialize_and_start_gpdb_segments "$@"
        ;;
    "standby")
        setup_version_config
        setup_master
        setup_segment_authorized_keys
        setup_hostfile_gpinitsystem
        check_hostfile_gpinitsystem
        initialize_and_start_gpdb_standby
        ;;
    *)
        error_and_exit "Invalid deployment mode: ${GREENPLUM_DEPLOYMENT}"
        ;;
esac
