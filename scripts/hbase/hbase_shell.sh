#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber

HBASE_CONTAINER_NAME=${1:-"regionserver"}

sudo docker exec -it "hbase_$HBASE_CONTAINER_NAME" /var/lib/cluster/bin/hbase shell
