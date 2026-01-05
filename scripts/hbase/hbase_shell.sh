#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber

/var/lib/cluster/scripts/hbase/hbase.sh shell $@ <&0
