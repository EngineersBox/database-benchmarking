FROM alpine:latest

ARG REPOSITORY="https://github.com/EngineersBox/cassandra.git"
ARG COMMIT_ISH="cassandra-5.0"

# RUN DEBIAN_FRONTEND="noninteractive" apt-get update && apt-get -y install tzdata

# explicitly set user/group IDs
RUN set -eux \
	&& addgroup -S cassandra \
	&& adduser -S -s bash -g cassandra cassandra

RUN apk add gcc \
        g++ \
        gdb \
        clang\
        make \
        cmake \
        autoconf \
        automake \
        libtool \
        valgrind \
        dos2unix \
        rsync \
        tar \
        python3 \
        python3-dev \
        git \
        unzip \
        wget \
        ca-certificates \
        openssl \
        openjdk17-jdk \
        openjdk17-jre \
        git \
        apache-ant \
        libxml2-utils \
        jemalloc-dev \
        jemalloc \
        procps \
        iproute2 \
        numactl \
        iptables \
        tzdata \
        bash

RUN ln -sT "$(readlink -f /usr/lib/libjemalloc.so.2)" /usr/local/lib/libjemalloc.so
RUN ldconfig

RUN echo 'export JAVA_HOME=$(readlink -f /usr/bin/javac | sed "s:bin/javac::")' >> /etc/.profile

# Docker cache avoidance to detect new commits
ARG CACHEBUST=0

WORKDIR /var/lib
RUN git clone "$REPOSITORY" cassandra_repo

WORKDIR /var/lib/cassandra_repo
RUN git checkout "$COMMIT_ISH"
# Build the artifacts
RUN ant artifacts
# Untar everything into the correct place
RUN export BASE_VERSION=$(xmllint --xpath 'string(/project/property[@name="base.version"]/@value)' build.xml) \
    && tar -xvf "build/apache-cassandra-$BASE_VERSION-SNAPSHOT-bin.tar.gz" --directory=/var/lib \
    && mv /var/lib/apache-cassandra-$BASE_VERSION-SNAPSHOT /var/lib/cassandra
# We will mount the config into the container later in a different location
RUN rm -rf /var/lib/cassandra/conf

WORKDIR /
RUN rm -rf /var/lib/cassandra_repo

ENV CASSANDRA_HOME /var/lib/cassandra
ENV CASSANDRA_CONF /etc/cassandra
RUN echo "export PATH=\"$CASSANDRA_HOME/bin:\$PATH\""

COPY docker-entrypoint.sh /usr/local/bin
ENTRYPOINT ["docker-entrypoint.sh"]

USER cassandra
# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
EXPOSE 7000 7001 7199 9042 9160
CMD ["cassandra", "-R", "-f"]
