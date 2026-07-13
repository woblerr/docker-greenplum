#!/usr/bin/env bash

uid=$(id -u)

if [ "${uid}" = "0" ]; then
    # Custom time zone.
    if [ "${TZ}" != "Etc/UTC" ]; then
        cp /usr/share/zoneinfo/${TZ} /etc/localtime
        echo "${TZ}" > /etc/timezone
    fi
    # Custom user group.
    if [ "${GREENPLUM_GROUP}" != "gpadmin" ] || [ "${GREENPLUM_GID}" != "1001" ]; then
        groupmod -g ${GREENPLUM_GID} -n ${GREENPLUM_GROUP} gpadmin
    fi
    # Custom user.
    if [ "${GREENPLUM_USER}" != "gpadmin" ] || [ "${GREENPLUM_UID}" != "1001" ]; then
        java_home_path=$(dirname $(dirname $(readlink -f $(which java))))
        usermod -g ${GREENPLUM_GID} -l ${GREENPLUM_USER} -u ${GREENPLUM_UID} -m -d /home/${GREENPLUM_USER} gpadmin
        echo "source /usr/local/greenplum-db/greenplum_path.sh" > /home/${GREENPLUM_USER}/.bashrc
        echo "export JAVA_HOME=/${java_home_path}" >> /home/${GREENPLUM_USER}/.bashrc
        echo 'export PATH="/usr/local/pxf/bin:${PATH}"' >> /home/${GREENPLUM_USER}/.bashrc
        echo "export PXF_BASE=${GREENPLUM_DATA_DIRECTORY}/pxf" >> /home/${GREENPLUM_USER}/.bashrc
        mkdir -m 700 -p /home/${GREENPLUM_USER}/.ssh
        mkdir -p /home/${GREENPLUM_USER}/pxf
        ssh-keygen -q -f /home/${GREENPLUM_USER}/.ssh/id_rsa -t rsa -N ""
    fi
    # If user or group was customized.
    if [ "${GREENPLUM_USER}" != "gpadmin" ] || [ "${GREENPLUM_UID}" != "1001" ] \
        || [ "${GREENPLUM_GROUP}" != "gpadmin" ] || [ "${GREENPLUM_GID}" != "1001" ]; then
        chown -R ${GREENPLUM_USER}:${GREENPLUM_GROUP} \
          /usr/local/greenplum-db \
          /usr/local/pxf
    fi
    # Correct user:group.
    chown -R ${GREENPLUM_USER}:${GREENPLUM_GROUP} \
        /home/${GREENPLUM_USER} \
        ${GREENPLUM_DATA_DIRECTORY} \
        /docker-entrypoint-initdb.d
fi

# Start SSH server.
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi
mkdir -p /run/sshd
/usr/sbin/sshd
sleep 2

# Execute command.
if [ "${uid}" = "0" ]; then
    exec gosu ${GREENPLUM_USER} "$@"
else
    exec "$@"
fi
