#!/bin/bash

set -e

PWD=$(pwd)

case "$PWD" in
    */cassandra-benchmarking)
        echo "[ERROR] Script should be run from cassandra-benchmarking directory, not from '$PWD' Exiting.";
        exit 1;;
    *) ;;
esac

source scripts/parameters.sh

cat <<EOF
Parameters:

DISTRIBUTION = $DISTRIBUTION
IMAGE = $IMAGE
GITHUB_USERNAME = $GITHUB_USERNAME
REPOSITORY = $REPOSITORY
BRANCH = $BRANCH
CASSANDRA_VERSION = $CASSANDRA_VERSION

OTEL_COLLECTOR_JAR_VERSION = $OTEL_COLLECTOR_JAR_VERSION
OTEL_COLLECTOR_JAR_PATH = $OTEL_COLLECTOR_JAR_PATH
OTEL_JMX_JAR_VERSION = $OTEL_JMX_JAR_VERSION
OTEL_JMX_JAR_PATH = $OTEL_JMX_JAR_PATH
OTEL_AGENT_CONFIG_FILE = $OTEL_AGENT_CONFIG_FILE
OTEL_SERVICE_NAME = $OTEL_SERVICE_NAME

EOF

function unpack_tar() {
    curl -OL "https://downloads.apache.org/cassandra/$CASSANDRA_VERSION/apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz"
    curl -OL "https://downloads.apache.org/cassandra/$CASSANDRA_VERSION/apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz.sha256"
    echo "$(cat "apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz.sha256") apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz" > "apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz.sha256"
    sha256sum --check --status "apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz.sha256"
    tar xzf "apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz"
    mv "apache-cassandra-$CASSANDRA_VERSION" "$REPOSITORY"
}

function build_repo() {
    if test -d "$PWD/$REPOSITORY"; then
        cd "$REPOSITORY"
    else
        git clone --depth 1 --single-branch "https://github.com/$GITHUB_USERNAME/$REPOSITORY.git"
        cd "$REPOSITORY"
        git pull --unshallow
        git add remote upstream https://github.com/apache/cassandra
        git fetch upstream
    fi
    docker run \
        -v "$PWD:/tmp/build" \
        -w /tmp/build \
        --rm \
        --user cassandra \
        $IMAGE \
        ./build_cassandra.sh "$REPOSITORY" "$BRANCH" "$CASSANDRA_VERSION"
}

function start_docker() {
    docker compose up
    # docker run \
    #     --network=cassandra \
    #     -p 3000:3000 \
    #     -p 4317:4317 \
    #     -p 4318:4318 \
    #     -v "$PWD/log:/var/log/otel" \
    #     -v "$PWD/config/otel/otel-collector-config.yaml:/otel-lgtm/otelcol-config.yaml" \
    #     -v "$PWD/config/otel/grafana-dashboard-jvm.json:/otel-lgtm/grafana-dashboard-jvm.json" \
    #     -v "$PWD/config/otel/grafana-dashboards.yaml:/otel-lgtm/grafana-dashboards.yaml" \
    #     -v "$PWD/opentelemetry-jmx-metrics.jar:$OTEL_JMX_JAR_PATH" \
    #     --name "otel" \
    #     -d \
    #     grafana/otel-lgtm
    # TODO: Fix user permissions, at the moment "cassandra" acts like root

    #     --network=cassandra \
    #     -p 7000:7000 \
    #     -p 7001:7001 \
    #     -p 7199:7199 \
    #     -p 9042:9042 \
    #     -p 9160:9160 \
    #     -v "$PWD/config/otel/otel.properties:$OTEL_AGENT_CONFIG_FILE" \
    #     -v "$PWD/opentelemetry-jmx-metrics.jar:$OTEL_JMX_JAR_PATH" \
    #     -v "$PWD/opentelemetry-javaagent.jar:$OTEL_COLLECTOR_JAR_PATH" \
    #     -v "$PWD/$REPOSITORY/conf:/etc/cassandra" \
    #     -v "$PWD/config/cassandra/cassandra.yaml:/etc/cassandra/cassandra.yaml" \
    #     -v "$PWD/$REPOSITORY:/var/lib/cassandra" \
    #     --name "cassandra" \
    #     -d \
    #     $IMAGE
}

jvm_server_opts=(jvm-server.options jvm11-server.options jvm17-server.options)
read -r -d '' jvm_props <<EOF || :
-javaagent:$OTEL_COLLECTOR_JAR_PATH
-Dotel.javaagent.configuration-file=$OTEL_AGENT_CONFIG_FILE
-Dotel.service.name=$OTEL_SERVICE_NAME
EOF

function instrument_cassandra() {
    wget "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/$OTEL_COLLECTOR_JAR_VERSION/opentelemetry-javaagent.jar"
    wget "https://github.com/open-telemetry/opentelemetry-java-contrib/releases/download/$OTEL_JMX_JAR_VERSION/opentelemetry-jmx-metrics.jar"
    for opt in ${jvm_server_opts[@]}; do
        echo "$jvm_props" >> "$PWD/$REPOSITORY/conf/$opt"
    done
}

case $DISTRIBUTION in
    tar) unpack_tar ;;
    repo) build_repo ;;
    *) echo "[ERROR] Invalid distribution option: $DISTRIBUTION, must be one of [tar,repo]"; exit 1 ;;
esac

instrument_cassandra
start_docker

