#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber

hbase shell $@
