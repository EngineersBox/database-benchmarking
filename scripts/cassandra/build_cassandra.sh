#!/bin/bash

REPOSITORY=$1
BRANCH=$2
CASSANDRA_VERSION=$3

PWD=$(pwd)

cd "$REPOSITORY"
git checkout "$BRANCH"
git pull

ant artifacts

build_version=$(xmllint -xpath 'string(/project/property[@name="base.version"/@value]) build.xml')
mv "build/apache-cassandra-$build_version-SNAPSHOT-bin.tar.gz" "$PWD/apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz"
cd "$PWD"
tar xzf "apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz"
