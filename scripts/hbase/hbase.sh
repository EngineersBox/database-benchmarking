#!/usr/bin/env bash

REGIONSERVERS_FILE_PATH="/var/lib/cluster/config/hbase/regionservers"
source /var/lib/cluster/scripts/logging.sh
init_logger

set -o pipefail -o noclobber
target=""

function find_container_target() {
    container_names=$(docker ps --format "{{.Names}}")
    exec_able_names="hbase_regionserver
    hbase_master
    hbase_zookeeper"
    readarray -t targets < <(comm -12 <(echo "$container_names" | sort) <(echo "$exec_able_names" | sort))
    if [ ${#targets[@]} -le 0 ]; then
        return 1
    fi
    target="${targets[0]}"
    return 0
}

function get_regionserver() {
    if [ ! -f $REGIONSERVERS_FILE_PATH ]; then
        log_fatal "Hbase regionservers file $REGIONSERVERS_FILE_PATH does not exist"
        exit 1
    fi
    target=$(head -n 1 $REGIONSERVERS_FILE_PATH)
}

find_container_target
is_remote=$?
if [ "$is_remote" -eq 1 ]; then
    log_warn "No HBase container on host machine, assuming remote execution"
    get_regionserver
    log_info "Executing on remote region server: $target"
    sudo ssh cluster@"$target" /var/lib/cluster/scripts/hbase/hbase.sh $@ <&0
else
    log_info "Executing in container: $target"
    sudo docker exec -it "$target" /var/lib/hbase/bin/hbase $@ <&0
fi
