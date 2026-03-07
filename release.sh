#!/usr/bin/env bash

ARCHIVE_NAME=$1
OTEL_COLLECTOR_JAR_VERSION=v2.6.0
OTEL_JMX_JAR_VERSION=v1.35.0

if ! test -f opentelemetry-javaagent.jar; then
    wget "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/$OTEL_COLLECTOR_JAR_VERSION/opentelemetry-javaagent.jar"
fi
if ! test -f opentelemetry-jmx-metrics.jar; then
    wget "https://github.com/open-telemetry/opentelemetry-java-contrib/releases/download/$OTEL_JMX_JAR_VERSION/opentelemetry-jmx-metrics.jar"
fi

tar -czf "$ARCHIVE_NAME.tar.gz" --group=cluster --owner=cluster \
    benchmarking/ \
    config/ \
    docker/ \
    init/ \
    etc/ \
    scripts/ \
    stress.yaml \
    opentelemetry-javaagent.jar \
    opentelemetry-jmx-metrics.jar
