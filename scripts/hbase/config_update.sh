#!/usr/bin/env bash

EXEC_ABLE_CONTAINER_NAMES="hbase_regionserver
hbase_master"

source /var/lib/cluster/scripts/common/docker.sh
source /var/lib/cluster/scripts/logging.sh

init_logger \
    --journal \
    --tag "hbase_config_update" \
    --level VERBOSE

function on_error() {
    log_fatal "Failed to update config for HBase"
}

set -o errexit -o pipefail -o noclobber
trap on_error ERR

function print_help() {
    log_info "Usage: scripts/hbase/run.sh <required> [<options>]"
    log_info "Required:"
    log_info "    -s | --scheduler=<class name> Scheduler factory class to use"
    log_info "    -q | --queue_type=<type>      Queue type for the scheduler to use"
    log_info "    -r | --read_ratio=<float>     Percentage of all queues to dedicate to read operations"
    log_info "    -c | --scan_ratio=<float>     Percentage of read queues to dedicate to scan operations"
    log_info "    -a | --handler_factor=<float> Division of queues to handlers"
    log_info "    -d | --handler_count=<count>  Number of query handlers"
    log_info "Optional:"
    log_info "    -n | --node_role=<role>       Container role to reload. Must be one of 'master' or 'regionserver'. Will be auto-detected if not provided"
    log_info "    -t | --target=<node>          Execute this remotely on a given node"
}

# Note that options with a ':' require an argument
LONGOPTS=help,node_role:,scheduler:,queue_type:,read_ratio:,scan_ratio:,handler_factor:,handler_count:,target:
OPTIONS=hn:s:q:r:c:a:d:t:

# 1. Temporarily store output to be able to check for errors
# 2. Activate quoting/enhanced mode (e.g. by writing out \u201c--options\u201d)
# 3. Pass arguments only via   -- "$@"   to separate them correctly
# 4. If getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# Read getopt's output this way to handle the quoting right:
eval set -- "$PARSED"

container=""
scheduler=""
queue_type=""
read_ratio=""
scan_ratio=""
handler_factor=""
handler_count=""
target=""
# Handle options in order and nicely split until we see --
while true; do
    case "$1" in
        -h|--help)
            print_help
            exit 1
            ;;
        -n|--node_role)
            container="hbase_$2"
            shift 2
            ;;
        -s|--scheduler)
            scheduler="$2"
            shift 2
            ;;
        -q|--queue_type)
            queue_type="$2"
            shift 2
            ;;
        -r|--read_ratio)
            read_ratio="$2"
            shift 2
            ;;
        -c|--scan_ratio)
            scan_ratio="$2"
            shift 2
            ;;
        -a|--handler_factor)
            handler_factor="$2"
            shift 2
            ;;
        -d|--handler_count)
            handler_count="$2"
            shift 2
            ;;
        -t|--target)
            target="$2"
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

log_info "Sourcing node environment"
source /var/lib/cluster/node_env

function set_config_property() {
    local key="$1"
    local value="$2"
    local file="hbase-site.xml"
    local new_file="$file.new"
    xmlstarlet ed \
        -u "//property/name[text()='$key']/following-sibling::value" \
        -v "$value" \
        "$file" \
        > "$new_file"
    rm "$file"
    mv "$new_file" "$file"
}

if [ ! -z "$target" ]; then
    log_info "Executing on remote node: $target"
    # Disable host key checking to prevent prompting to accept new key
    # which allows this script to be used in automation
    sudo ssh -oStrictHostKeyChecking=no "$target" /var/lib/cluster/scripts/hbase/config_update.sh \
        --scheduler="$scheduler" \
        --queue_type="$queue_type" \
        --read_ratio="$read_ratio" \
        --scan_ratio="$scan_ratio" \
        --handler_factor="$handler_factor" \
        --handler_count="$handler_count"
    exit $?
fi
find_container_target "$EXEC_ABLE_CONTAINER_NAMES"
container="$target"

log_info "Stopping container $container"
sudo docker stop "$container"

log_info "Updating configuration"
pushd /var/lib/cluster/config/hbase

log_info "Setting scheduler: $scheduler"
set_config_property \
    "hbase.region.server.rpc.scheduler.factory.class" \
    "org.apache.hadoop.hbase.regionserver.$scheduler"

log_info "Setting queue type: $queue_type"
set_config_property \
    "hbase.ipc.server.callqueue.type" \
    "$queue_type"

log_info "Setting read ratio: $read_ratio"
set_config_property \
    "hbase.ipc.server.callqueue.read.ratio" \
    "$read_ratio"

log_info "Setting scan ratio: $scan_ratio"
set_config_property  \
    "hbase.ipc.server.callqueue.scan.ratio" \
    "$scan_ratio"

log_info "Setting handler factor: $handler_factor"
set_config_property  \
    "hbase.ipc.server.callqueue.handler.factor" \
    "$handler_factor"

log_info "Setting handler count: $handler_count"
set_config_property  \
    "hbase.regionserver.handler.count" \
    "$handler_count"

popd

log_info "Starting container $container"
sudo docker start "$container"

SLEEP_DURATION=10
log_info "Sleeping for $SLEEP_DURATION seconds for stability"
sleep $SLEEP_DURATION

sudo docker ps -a
