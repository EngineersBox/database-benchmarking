#!/usr/bin/env bash

CASSANDRA_IMAGE="${CASSANDRA_IMAGE:-ghcr.io/engineersbox/cassandra}"
CASSANDRA_TAG="${CASSANDRA_TAG:-5.0}"

OTEL_IMAGE="${OTEL_IMAGE:-ghcr.io/engineersbox/otel-lgtm}"
OTEL_TAG="${OTEL_TAG:-latest}"

OTEL_COLLECTOR_JAR_VERSION="${OTEL_JAR_VERSION:-"v2.2.0"}"
OTEL_COLLECTOR_JAR_PATH="${OTEL_JAR_PATH:-"/var/lib/otel/opentelemetry-javaagent.jar"}"
# Using v1.33.0 results in OTEL failing to start since collector v2.2.0 doesnt have the hash
# for it yet, causing it to terminate
OTEL_JMX_JAR_VERSION="${OTEL_JMX_JAR_VERSION:-"v1.32.0"}"
OTEL_JMX_JAR_PATH="${OTEL_JMX_JAR_PATH:-"/var/lib/otel/opentelemetry-jmx-metrics.jar"}"
OTEL_AGENT_CONFIG_FILE="${OTEL_AGENT_CONFIG_FILE:-"/etc/otel/otel.properties"}"
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-"Cassandra"}"
