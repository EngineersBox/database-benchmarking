#!/usr/bin/env bash

source /var/lib/cluster/scripts/logging.sh

init_logger \
    --journal \
    --tag "hbase_ycsb_benchmarking" \
    --level VERBOSE

function on_error() {
    log_fatal "Failed to run benchmarking for HBase"
}

set -o errexit -o pipefail -o noclobber
trap on_error ERR

if [[ "$#" -lt 1 ]]; then
    log_error "Usage: run.sh <load workload path> <run workload path> [table name] [column family name]"
    exit 1
fi

LOAD_WORKLOAD="$1"
RUN_WORKLOAD="$2"
TABLE="${3:-"usertable"}"
COLUMN_FAMILY="${4:-"family"}"

log_info "Sourcing node environment"
source /var/lib/cluster/node_env

pushd /var/lib/cluster

log_info "Creating HBase $TABLE with even splits across all $region_server_count region servers"
echo "n_splits = $((10 * region_server_count)); create '$TABLE', '$COLUMN_FAMILY', {SPLITS => (1..n_splits).map {|i| \"user#{1000+i*(9999-1000)/n_splits}\"}}" | /var/lib/cluster/scripts/hbase/hbase_shell.sh

popd

pushd /var/lib/cluster/ycsb

log_info "Warming up HBase and loading $LOAD_WORKLOAD data"
sudo bin/ycsb load hbase2 \
    -P "$LOAD_WORKLOAD" \
    -s \
    -cp /var/lib/cluster/config/hbase \
    -p table="$TABLE" \
    -p columnfamily="$COLUMN_FAMILY"
log_info "Completed warm up"

log_info "Running workload $RUN_WORKLOAD"
sudo bin/ycsb run hbase2 \
    -P "$RUN_WORKLOAD" \
    -s \
    -cp /var/lib/cluster/config/hbase \
    -p table="$TABLE" \
    -p columnfamily="$COLUMN_FAMILY" \
    -p threads=4 \
    -p clientbuffering=true
log_info "Completed benchmarking"

popd
