#!/usr/bin/env bash

REGIONSERVERS_FILE_PATH="/var/lib/cluster/config/hbase/regionservers"
EXEC_ABLE_CONTAINER_NAMES="hbase_regionserver
hbase_master
hbase_zookeeper"

source /var/lib/cluster/scripts/common/docker.sh
source /var/lib/cluster/scripts/logging.sh
init_logger

set -o pipefail -o noclobber
target=""

function get_regionserver() {
    if [ ! -f "$REGIONSERVERS_FILE_PATH" ]; then
        log_fatal "Hbase regionservers file $REGIONSERVERS_FILE_PATH does not exist"
        exit 1
    fi
    target=$(head -n 1 $REGIONSERVERS_FILE_PATH)
}

find_container_target "$EXEC_ABLE_CONTAINER_NAMES"
is_remote=$?
if [ "$is_remote" -eq 1 ]; then
    log_warn "No HBase container on host machine, assuming remote execution"
    get_regionserver
    log_info "Executing on remote region server: $target"
    sudo ssh "$target" /var/lib/cluster/scripts/hbase/hbase.sh $@ <&0
else
    log_info "Executing in container: $target"
    docker_opts=""
    tty_sensitive_docker_opts
    sudo docker exec "$docker_opts" "$target" /var/lib/hbase/bin/hbase $@ <&0
fi
