#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <workload path>"
    exit 1
fi

workload="$1"

systemd-run \
    --uid=cluster \
    --gid=cluster \
    --unit=hbase_benchmarking \
    /var/lib/cluster/bencharmking/run.sh \
    --load_workload="$workload" \
    --run_workload="$workload" \
    --hbase_configs=/var/lib/cluster/bencharmking/hbase/hbase_configs.txt
