#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber

CONTAINER_NAME=${1:-"hbase_regionserver"}

sudo docker exec -it "$CONTAINER_NAME" /var/lib/cluster/bin/hbase shell
