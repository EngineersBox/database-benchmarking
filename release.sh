#!/usr/bin/env bash

ARCHIVE_NAME=$1
OTEL_COLLECTOR_JAR_VERSION=v2.6.0
OTEL_JMX_JAR_VERSION=v1.35.0

wget "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/$OTEL_COLLECTOR_JAR_VERSION/opentelemetry-javaagent.jar"
wget "https://github.com/open-telemetry/opentelemetry-java-contrib/releases/download/$OTEL_JMX_JAR_VERSION/opentelemetry-jmx-metrics.jar"

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

rm opentelemetry-javaagent.jar opentelemetry-jmx-metrics.jar
