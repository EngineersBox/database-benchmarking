#!/usr/bin/env bash

set -o pipefail -o noclobber

# Args:
#  $1: Exec-able container names
# Outputs:
#  $target: Contains matching container name if exists
# Returns:
#  1: If no matches found
#  0: Otherwise
function find_container_target() {
    local exec_able_container_names="$1"
    container_names=$(docker ps --format "{{.Names}}")
    readarray -t targets < <(comm -12 <(echo "$container_names" | sort) <(echo "$exec_able_container_names" | sort))
    if [ ${#targets[@]} -le 0 ]; then
        return 1
    fi
    export target="${targets[0]}"
    return 0
}

# Outputs:
#  $docker_opts: -it if a TTY, -i otherwise
function tty_sensitive_docker_opts() {
    docker_opts="-i"
    if [ -t 1 ]; then
        # Is a TTY
        docker_opts="-it"
    fi
}
