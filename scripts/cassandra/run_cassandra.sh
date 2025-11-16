#!/usr/bin/env bash

PWD=$(pwd)

case $(basename "$PWD") in
    cassandra-benchmarking) ;;
    *) echo "[ERROR] Script should be run from cassandra-benchmarking directory, not from '$PWD' Exiting.";
       exit 1;;
esac

if [ $# -ne 1 ]; then
    echo "Usage: run_cassandra.sh <refresh: y|n>"
    exit 1
fi

ENV_FILE="docker/instance/.env"

if [ ! -f "$ENV_FILE"  ]; then
    echo "[ERROR] Missing required env file: $ENV_FILE"
    exit 1
fi
if [ "$(grep -Ec '=<.*>' docker/instance/.env)" -ne 0 ]; then
    echo "[ERROR] Env file contains missing values for templated properties: $ENV_FILE"
    exit 1
fi

CLEAR_ALL="$1"
if [ "${CLEAR_ALL,,}" = "y" ]; then
    sudo vmprobe cache evict /mnt/nvme/cassandra_data  
    echo "[INFO] Evicted all page cache entries"
    sudo rm -rf /mnt/nvme/cassandra_data/*
    echo "[INFO] Cleaned cassandra data mount"
    pushd docker/instance
    docker compose down
    sudo docker compose down
    popd
    echo "[INFO] Stopped and removed previous cassandra container"
fi

echo "[INFO] Env file parameters:"
cat $ENV_FILE

echo "[INFO] Starting Cassandra..."

pushd docker/instance
sudo docker compose up -d otel-kernel otel-hostmetrics
docker compose up -d cassandra
popd

