#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber

sudo su -c /bin/bash -c "/var/lib/hadoop/bin/hdfs $*" - hadoop
