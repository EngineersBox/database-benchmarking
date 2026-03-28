#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <workload path> <user>"
    exit 1
fi

workload="$1"
run_user="$2"

systemd-run \
    --uid="$run_user"\
    --unit=hbase_benchmarking \
    /var/lib/cluster/benchmarking/hbase/run.sh \
    --load_workload="$workload" \
    --run_workload="$workload" \
    --hbase_configs=/var/lib/cluster/bencharmking/hbase/hbase_configs.txt
