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

function print_help() {
    log_info "Usage: cassandra/run.sh [<options>]"
    log_info "Options:"
    log_info "    -h | --help                 Print this help message"
    log_info "    -l | --load_workload=<path> Path to workload for loading benchmarking data (REQUIRED)"
    log_info "    -r | --run_workload=<path>  Path to workload for running benchmark (REQUIRED)"
    log_info "    -d | --driver_config=<path> Path to Cassandra driver configuration (REQUIRED)"
    log_info "    -k | --keyspace=<name>      HBase benchmarking keyspace name (default: ycsb)"
    log_info "    -t | --table=<name>         HBase benchmarking table name (default: usertable)"
}

# Note that options with a ':' require an argument
LONGOPTS=help,load_workload:,run_workload:,driver_config,keyspace:,table:
OPTIONS=hl:r:d:k:t:

# 1. Temporarily store output to be able to check for errors
# 2. Activate quoting/enhanced mode (e.g. by writing out \u201c--options\u201d)
# 3. Pass arguments only via   -- "$@"   to separate them correctly
# 4. If getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# Read getopt's output this way to handle the quoting right:
eval set -- "$PARSED"

load_workload=""
run_workload=""
driver_config=""
keyspace="ycsb"
table="usertable"
# Handle options in order and nicely split until we see --
while true; do
    case "$1" in
        -h|--help)
            print_help
            exit 1
            ;;
        -l|--load_workload)
            load_workload="$2"
            shift 2
            ;;
        -r|--run_workload)
            run_workload="$2"
            shift 2
            ;;
        -d|--driver_config)
            driver_config="$2"
            shift 2
            ;;
        -k|--keyspace)
            keyspace="$2"
            shift 2
            ;;
        -t|--table)
            table="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            log_fatal "Unknown option encountered: $1"
            exit 3
            ;;
    esac
done

missing_parameters=""
if [ -z "$load_workload" ]; then
    missing_parameters="$missing_parameters --load_workload"
fi
if [ -z "$run_workload" ]; then
    missing_parameters="$missing_parameters --run_workload"
fi
if [ -z "$driver_config" ]; then
    missing_parameters="$missing_parameters --driver_config"
fi
if [ ! -z "$missing_parameters" ]; then
    log_fatal "Missing required parameters:$missing_parameters"
    print_help
    exit 1
fi

pushd /var/lib/cluster

read -r -d '' CQL_SCRIPT << EOM
create keyspace $keyspace with replication = {'class' : 'SimpleStrategy', 'replication_factor': 1 };
create table $keyspace.$table (
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

log_info "Creating keyspace $keyspace and table $table"
/var/lib/cluster/scripts/cassandra/cqlsh.sh -e "$CQL_SCRIPT"

popd

pushd /var/lib/cluster/ycsb

log_info "Warming up Cassandra and loading $load_workload data"
sudo bin/ycsb load cassandra \
    -P "$load_workload" \
    -s \
    -p cassandra.driverconfig=/var/lib/cluster/ycsb/base_profile.dat
log_info "Completed warm up"

log_info "Running workload $run_workload"
sudo bin/ycsb run cassandra \
    -P "$run_workload" \
    -s \
    -p cassandra.driverconfig="$driver_config"
log_info "Completed benchmarking"

popd
