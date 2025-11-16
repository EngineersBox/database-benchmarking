#!/usr/bin/env bash

PWD=$(pwd)

case $(basename "$PWD") in
    cassandra-benchmarking) ;;
    *) echo "[ERROR] Script should be run from cassandra-benchmarking directory, not from '$PWD' Exiting.";
       exit 1;;
esac

if [ $# -ne 1 ]; then
    echo "Usage: run_otel.sh <refresh: y|n>"
    exit 1
fi

CLEAR_ALL="$1"
if [ "${CLEAR_ALL,,}" = "y" ]; then
    sudo vmprobe cache evict data
    echo "[INFO] Evicted all page cache entries"
    sudo rm -rf data
    echo "[INFO] Cleaned OTEL data mount"
    pushd docker/collector
    docker compose down
    popd
    echo "[INFO] Stopped and removed previous OTEL container"
fi

echo "[INFO] Starting OTEL... " 

pushd docker/collector
docker compose up -d 
popd

