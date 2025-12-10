#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber

container_names=$(docker ps --format "{{.Names}}")
exec_able_names="hbase_regionserver
hbase_master
hbase_zookeeper"

readarray -t targets < <(comm -12 <(echo "$container_names" | sort) <(echo "$exec_able_names" | sort))
if [ ${#targets[@]} -le 0 ]; then
    echo "No viable HBase container to exec within from list '${exec_able_names//$'\n'/ }'"
    exit 1
fi

sudo docker exec -it "${targets[0]}" /var/lib/hbase/bin/hbase $@
