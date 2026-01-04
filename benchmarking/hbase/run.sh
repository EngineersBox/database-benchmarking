#!/usr/bin/env bash

source /var/lib/cluster/node_env
source /var/lib/cluster/scripts/logging.sh

init_logger \
    --journal \
    --tag "hbase_ycsb_benchmarking" \
    --level VERBOSE

function on_error() {
    log_fatal "Failed to run benchmarking for HBase"
}

trap on_error ERR
set -ex

if [[ "$#" -lt 1 ]]; then
    log_error "Usage: run.sh <workload file path> [table name] [column family name]"
    exit 1
fi

WORKLOAD="$1"
TABLE="${2:-"usertable"}"
COLUMN_FAMILY="${3:-"family"}"

pushd /var/lib/cluster

log_info "Creating HBase $TABLE with even splits across all $region_server_count region servers"
echo "n_splits = $((10 * region_server_count)); create '$TABLE', '$COLUMN_FAMILY', {SPLITS => (1..n_splits).map {|i| \"user#{1000+i*(9999-1000)/n_splits}\"}}" | ./scripts/hbase_shell.sh

popd

pushd /var/lib/cluster/ycsb

log_info "Warming up HBase and loading $WORKLOAD data"
bin/ycsb load hbase2 \
    -P "$WORKLOAD" \
    -cp /var/lib/cluster/config/hbase \
    -p table="$TABLE" \
    -p columnfamily="$COLUMN_FAMILY"
log_info "Completed warm up"

log_info "Running workload $WORKLOAD"
bin/ycsb run hbase2 \
    -P "$WORKLOAD" \
    -cp /var/lib/cluster/config/hbase \
    -p table="$TABLE" \
    -p columnfamily="$COLUMN_FAMILY" \
    -p clientbuffering=true \
    -p durability=true
log_info "Completed benchmarking"

popd
