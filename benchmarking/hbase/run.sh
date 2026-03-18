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

function print_help() {
    log_info "Usage: hbase/run.sh <required> [<options>]"
    log_info "Required:"
    log_info "    -r | --run_workload=<path>  Path to workload for running benchmark"
    log_info "    -b | --hbase_configs=<path> Path to file where each line is a set of configs"
    log_info "Options:"
    log_info "    -h | --help                 Print this help message"
    log_info "    -l | --load_workload=<path> Path to workload for loading benchmarking data, skips loading if not specified"
    log_info "    -t | --table=<name>         HBase benchmarking table name [Default: usertable]"
    log_info "    -c | --column_family=<name> HBase benchmarking column family name [Default: family]"
}

# Note that options with a ':' require an argument
LONGOPTS=help,load_workload:,run_workload:,hbase_configs:,table:,column_family:
OPTIONS=hl:r:b:t:c:

# 1. Temporarily store output to be able to check for errors
# 2. Activate quoting/enhanced mode (e.g. by writing out \u201c--options\u201d)
# 3. Pass arguments only via   -- "$@"   to separate them correctly
# 4. If getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# Read getopt's output this way to handle the quoting right:
eval set -- "$PARSED"

load_workload=""
run_workload=""
hbase_configs=""
table="usertable"
column_family="family"
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
        -b|--hbase_configs)
            hbase_configs="$2"
            shift 2
            ;;
        -t|--table)
            table="$2"
            shift 2
            ;;
        -c|--column_family)
            column_family="$2"
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

if [ -z "$run_workload" ]; then
    missing_parameters="$missing_parameters --run_workload"
fi
if [ -z "$hbase_configs" ]; then
    missing_parameters="$missing_parameters --hbase_configs"
fi
if [ ! -z "$missing_parameters" ]; then
    log_fatal "Missing required parameters:$missing_parameters"
    print_help
    exit 1
fi

log_info "Sourcing node environment"
source /var/lib/cluster/node_env

pushd /var/lib/cluster
set +e

log_info "Creating HBase $table with even splits across all $region_server_count region servers"
echo "n_splits = $((10 * region_server_count)); create '$table', '$column_family', {SPLITS => (1..n_splits).map {|i| \"user#{1000+i*(9999-1000)/n_splits}\"}}" | /var/lib/cluster/scripts/hbase/hbase_shell.sh -n
table_exists=$?
if [ "$table_exists" -ne 0 ]; then
    log_warn "Table $table already exists, skipping creation"
fi

set -e
popd

pushd /var/lib/cluster/ycsb

if [ -z "$load_workload" ]; then 
    log_info "No load workload specified, skipping"
else
    log_info "Warming up HBase and loading $load_workload data"
    sudo bin/ycsb load hbase2 \
        -P "$load_workload" \
        -s \
        -cp /var/lib/cluster/config/hbase \
        -p table="$table" \
        -p columnfamily="$column_family"
    log_info "Sleeping for 30 seconds to allow cluster to settle"
    sleep 30
    log_info "Completed warm up"
fi

log_info "Shuting down cluster"
/var/lib/cluster/scripts/hbase/hbase.sh master stop --shutDownCluster
sleep 20

config_count=$(wc -l "$hbase_configs")
log_info "Running workload $run_workload for $config_count configurations"

workload_name=$(basename "$run_workload")

while IFS="" read -r line || [ -n "$line" ]; do
    IFS=" " read -r config_name options <<< "$line"
    for node_ip in "${NODE_IPS[@]}"; do
        log_info "Updating configuration $config_name on node $node_ip"
        /var/lib/cluster/scripts/hbase/config_update.sh $options --target="$node_ip"
    done
    log_info "Sleeping for 30 seconds to allow cluster to settle"
    sleep 30
    log_info "Running workload $workload_name on configuration $config_name"
    output_dir="/var/lib/cluster/benchmarking/hbase/results/$workload_name"
    mkdir -p "$output_dir"
    sudo bin/ycsb run hbase2 \
        -P "$run_workload" \
        -s \
        -cp /var/lib/cluster/config/hbase \
        -p table="$table" \
        -p columnfamily="$column_family" \
        -p clientbuffering=true \
        -p exporter="site.ycsb.measurements.exporter.JSONArrayMeasurementsExporter" \
        -p exportfile="$output_dir/$config_name.json"
done < "$hbase_configs"

log_info "Completed benchmarking"

popd
