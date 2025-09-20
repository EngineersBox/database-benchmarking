FROM debian:bookworm-slim
LABEL org.opencontainers.image.source https://github.com/EngineersBox/database-benchmarking

ARG REPOSITORY="https://github.com/EngineersBox/hbase.git"
ARG BRANCH="hbase-2.6"
ARG COMMIT=""
ARG UID=1000
ARG GID=1000
ARG OTEL_COLLECTOR_JAR_VERSION=v2.6.0
ARG OTEL_JMX_JAR_VERSION=v1.35.0

RUN DEBIAN_FRONTEND="noninteractive" apt-get update && apt-get -y install tzdata

# explicitly set user/group IDs
RUN set -eux \
	&& groupadd --system --gid=$UID hbase \
	&& useradd --system --create-home --shell=/bin/bash --gid=cassandra --uid=$GID hbase

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
RUN git clone "$REPOSITORY" hbase_repo

WORKDIR /var/lib/hbase_repo
RUN git checkout "$BRANCH"
RUN if [ "x$COMMIT" != "x" ]; then git checkout "$COMMIT"; fi
# Build the artifacts
RUN MAVEN_OPTS="-Xmx2g" mvn clean site install assembly:assembly -DskipTests -Prelease
RUN export BASE_VERSION=$(xmllint --xpath 'string(/project/version/@value)' pom.xml) \
    && tar -xvf "build/apache-hbase-$BASE_VERSION-SNAPSHOT-bin.tar.gz" --directory=/var/lib \
    && mv /var/lib/apache-hbase-$BASE_VERSION-SNAPSHOT /var/lib/hbase/
RUN rm -rf /var/lib/hbase/conf
RUN mkdir -p /var/lib/hbase/logs
RUN chown -R hbase:hbase /var/lib/hbase

WORKDIR /
RUN rm -rf /var/lib/hbase_repo

ENV HBASE_HOME /var/lib/hbase
ENV HBASE_CONF_DIR /etc/hbase
ENV PATH $HBASE_HOME/bin:$PATH

WORKDIR /var/lib
RUN mkdir -p otel
WORKDIR /var/lib/otel
RUN wget "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/$OTEL_COLLECTOR_JAR_VERSION/opentelemetry-javaagent.jar"
RUN wget "https://github.com/open-telemetry/opentelemetry-java-contrib/releases/download/$OTEL_JMX_JAR_VERSION/opentelemetry-jmx-metrics.jar"
RUN chown -R hbase:hbase /var/lib/otel

WORKDIR /
# COPY ../../scripts/docker-entrypoint.sh /usr/local/bin
# ENTRYPOINT ["docker-entrypoint.sh"]

USER hbase
# 16000: HMaster
# 16010: HMaster info web UI
# 16020: RegionServer
# 16030: RegionServer
# 8080: REST server
# 8085: REST server web UI
# 9090: Thrift server
# 9095: Thrift server
EXPOSE 16000 16010 16020 16030 8080 8085 9090 9095
CMD ["/var/lib/hbase/bin/start-hbase.sh"]
