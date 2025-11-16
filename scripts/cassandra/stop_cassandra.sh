#!/bin/bash

# docker container stop cassandra
# docker container stop otel
#
# docker container rm cassandra
# docker container rm otel

docker compose down

rm -rf apache-cassandra-5.0-beta1-bin.tar.gz \
    apache-cassandra-5.0-beta1-bin.tar.gz.sha256 \
    cassandra \
    opentelemetry-javaagent.jar \
    opentelemetry-jmx-metrics.jar
