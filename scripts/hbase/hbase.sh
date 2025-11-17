#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber

HBASE_CONTAINER_NAME="regionserver"

sudo docker exec -it "hbase_$HBASE_CONTAINER_NAME" /var/lib/hbase/bin/hbase $@
