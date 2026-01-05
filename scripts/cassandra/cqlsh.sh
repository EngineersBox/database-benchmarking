#!/usr/bin/env bash

TOPOLOGY_PROPERTIES_FILE_PATH="/var/lib/cluster/config/cassandra/cassandra-topology.properties"
EXECABLE_CONTAINER_NAMES="cassandra"

source /var/lib/cluster/scripts/common/docker.sh
source /var/lib/cluster/scripts/logging.sh
init_logger

set -o pipefail -o noclobber
target=""

function get_remote_node() {
    if [ ! -f "$TOPOLOGY_PROPERTIES_FILE_PATH" ]; then
        log_fatal "Cassandra topology properties file $TOPOLOGY_PROPERTIES_FILE_PATH does not exist"
        exit 1
    fi
    target=$(tail -n 1 "$TOPOLOGY_PROPERTIES_FILE_PATH" | sed -nE "s/^(.*)=.*$/\1/p")
}

find_container_target $EXECABLE_CONTAINER_NAMES
is_remote=$?
if [ "$is_remote" -eq 1 ]; then
    log_warn "No Cassandra container on host machine, assuming remote execution"
    get_remote_node 
    log_info "Executing on remote Cassandra node: $target"
    sudo ssh "$target" /var/lib/cluster/scripts/cassandra/cqlsh.sh $@ <&0
else
    log_info "Executing in container: $target"
    docker_opts=""
    tty_sensitive_docker_opts
    sudo docker exec "$docker_opts" "$target" /var/lib/cassandra/bin/cqlsh $@ <&0
fi
