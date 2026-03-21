#!/usr/bin/env bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <workload path> <driver config path>"
    exit 1
fi

workload="$1"
driver_config="$2"

systemd-run \
    --uid=cluster \
    --gid=cluster \
    --unit=cassandra_benchmarking \
    /var/lib/cluster/benchmarking/cassandra/run.sh \
    --load_workload="$workload" \
    --run_workload="$workload" \
    --drive_config="$driver_config"
