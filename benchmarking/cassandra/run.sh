#!/usr/bin/env bash

source /var/lib/cluster/node_env
source /var/lib/cluster/scripts/logging.sh

init_logger \
    --journal \
    --tag "cassandra_ycsb_benchmarking" \
    --level VERBOSE

function on_error() {
    log_fatal "Failed to run benchmarking for Cassandra"
}

trap on_error ERR
set -ex

if [[ "$#" -lt 1 ]]; then
    log_error "Usage: run.sh <workload file path> [keyspace name] [table name]"
    exit 1
fi

WORKLOAD="$1"
KEYSPACE="${2:-"ycsb"}"
TABLE="${3:-"usertable"}"

pushd /var/lib/cluster

read -r -d '' CQL_SCRIPT << EOM
create keyspace $KEYSPACE with replication = {'class' : 'SimpleStrategy', 'replication_factor': 1 };
create table $KEYSPACE.$TABLE (
    y_id varchar primary key,
    field0 varchar,
    field1 varchar,
    field2 varchar,
    field3 varchar,
    field4 varchar,
    field5 varchar,
    field6 varchar,
    field7 varchar,
    field8 varchar,
    field9 varchar
) with compaction = {'class': 'UnifiedCompactionStrategy'} and memtable = 'trie';
EOM

log_info "Creating keyspace $KEYSPACE and table $TABLE"
docker exec cassandra /var/lib/cassandra/bin/cqlsh -e "$CQL_SCRIPT"

popd

pushd /var/lib/cluster/ycsb

log_info "Warming up Cassandra and loading $WORKLOAD data"
bin/ycsb load cassandra \
    -P "$WORKLOAD" \
    -p cassandra.driverconfig=/var/lib/cluster/ycsb/base_profile.dat
log_info "Completed warm up"

log_info "Running workload $WORKLOAD"
bin/ycsb run cassandra \
    -P "$WORKLOAD" \
    -p cassandra.driverconfig=/var/lib/cluster/ycsb/base_profile.dat
log_info "Completed benchmarking"

popd
