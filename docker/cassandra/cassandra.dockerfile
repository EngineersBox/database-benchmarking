FROM debian:bookworm-slim
LABEL org.opencontainers.image.source https://github.com/EngineersBox/database-benchmarking

ARG REPOSITORY="https://github.com/EngineersBox/cassandra.git"
ARG BRANCH="cassandra-5.0"
ARG COMMIT=""
ARG UID=1000
ARG GID=1000
ARG OTEL_COLLECTOR_JAR_VERSION=v2.6.0
ARG OTEL_JMX_JAR_VERSION=v1.35.0

RUN DEBIAN_FRONTEND="noninteractive" apt-get update && apt-get -y install tzdata

# explicitly set user/group IDs
RUN set -eux \
	&& groupadd --system --gid=$UID cassandra \
	&& useradd --system --create-home --shell=/bin/bash --gid=cassandra --uid=$GID cassandra

RUN apt-get update \
    && apt-get install -y build-essential \
        gcc \
        g++ \
        gdb \
        clang-15 \
        clangd-15 \
        make \
        ninja-build \
        autoconf \
        automake \
        libtool \
        valgrind \
        locales-all \
        dos2unix \
        rsync \
        tar \
        python3 \
        python3-pip \
        python3-dev \
        git \
        unzip \
        wget \
        gpg \
        ca-certificates \
        openssl \
        openjdk-17-jdk \
        openjdk-17-jre \
        git \
        ant \
        libxml2-utils \
        libjemalloc2 \
        procps \
        iproute2 \
        numactl \
        iptables \
    && apt-get clean

RUN ln -sT "$(readlink -e /usr/lib/*/libjemalloc.so.2)" /usr/local/lib/libjemalloc.so \
	&& ldconfig

RUN update-java-alternatives --set /usr/lib/jvm/java-1.17.0-openjdk-amd64
RUN echo 'export JAVA_HOME=$(readlink -f /usr/bin/javac | sed "s:bin/javac::")' >> ~/.bashrc

# Docker cache avoidance to detect new commits
ARG CACHEBUST=0

WORKDIR /var/lib
RUN git clone "$REPOSITORY" cassandra_repo

WORKDIR /var/lib/cassandra_repo
RUN git checkout "$BRANCH"
RUN if [ "x$COMMIT" != "x" ]; then git checkout "$COMMIT"; fi
# Build the artifacts
RUN ant artifacts
# Untar everything into the correct place
RUN export BASE_VERSION=$(xmllint --xpath 'string(/project/property[@name="base.version"]/@value)' build.xml) \
    && tar -xvf "build/apache-cassandra-$BASE_VERSION-SNAPSHOT-bin.tar.gz" --directory=/var/lib \
    && mv /var/lib/apache-cassandra-$BASE_VERSION-SNAPSHOT /var/lib/cassandra
# We will mount the config into the container later in a different location
RUN rm -rf /var/lib/cassandra/conf
RUN mkdir -p /var/lib/cassandra/logs
RUN chown -R cassandra:cassandra /var/lib/cassandra

WORKDIR /
RUN rm -rf /var/lib/cassandra_repo

ENV CASSANDRA_HOME /var/lib/cassandra
ENV CASSANDRA_CONF /etc/cassandra
ENV PATH $CASSANDRA_HOME/bin:$PATH

WORKDIR /var/lib
RUN mkdir -p otel
WORKDIR /var/lib/otel
RUN wget "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/$OTEL_COLLECTOR_JAR_VERSION/opentelemetry-javaagent.jar"
RUN wget "https://github.com/open-telemetry/opentelemetry-java-contrib/releases/download/$OTEL_JMX_JAR_VERSION/opentelemetry-jmx-metrics.jar"
RUN chown -R cassandra:cassandra /var/lib/otel

WORKDIR /

USER cassandra
# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
EXPOSE 7000 7001 7199 9042 9160
CMD ["cassandra", "-f"]
