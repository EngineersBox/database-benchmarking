#!/usr/bin/env bash

docker exec cassandra /var/lib/cassandra/bin/cqlsh $@
