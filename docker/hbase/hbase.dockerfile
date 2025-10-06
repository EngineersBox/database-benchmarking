FROM debian:bookworm-slim
LABEL org.opencontainers.image.source=https://github.com/EngineersBox/database-benchmarking

ARG REPOSITORY="https://github.com/EngineersBox/hbase.git"
ARG BRANCH="2.6.3-kairos"
ARG COMMIT=""
ARG UID=1000
ARG GID=1000
ARG OTEL_COLLECTOR_JAR_VERSION=v2.6.0
ARG OTEL_JMX_JAR_VERSION=v1.35.0
ARG M2_SETTINGS_PATH="settings.xml"

RUN DEBIAN_FRONTEND="noninteractive" apt-get update && apt-get -y install tzdata

# Explicitly set user/group IDs
RUN set -eux \
	&& groupadd --system --gid=$UID hbase \
	&& useradd --system --create-home --shell=/bin/bash --gid=hbase --uid=$GID hbase

RUN apt-get update -y
RUN apt-get install -y \
    build-essential \
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
    maven \
    libxml2-utils \
    libjemalloc2 \
    procps \
    iproute2 \
    numactl \
    iptables
RUN apt-get clean

RUN ln -sT "$(readlink -e /usr/lib/*/libjemalloc.so.2)" /usr/local/lib/libjemalloc.so
RUN ldconfig

RUN update-java-alternatives --set /usr/lib/jvm/java-1.17.0-openjdk-amd64
RUN echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Docker cache avoidance to detect new commits
ARG CACHEBUST=0

# WORKDIR /var/lib
# RUN git clone "$REPOSITORY" hbase_repo

WORKDIR /var/lib/hbase_repo
# RUN git checkout "$BRANCH"
# RUN if [ "x$COMMIT" != "x" ]; then git checkout "$COMMIT"; fi
#
# # Maven settings for auth to repos
# COPY ["$M2_SETTINGS_PATH", "/opt/.m2/"]
#
# # Build the artifacts
# RUN mvn -s /opt/.m2/settings.xml clean package -DskipTests
# FIXME: This fails for some reason
# RUN mvn -s /opt/.m2/settings.xml assembly:single -DskipTests -Dhadoop.profile=3.0
#
# # Remove maven settings to avoid caching creds in image
# RUN rm -f /opt/.m2/settings.xml
#
# RUN export BASE_VERSION=$(xmllint --xpath 'string(/project/version/@value)' pom.xml)
# RUN tar -xvzf "build/apache-hbase-$BASE_VERSION-SNAPSHOT-bin.tar.gz" --directory=/var/lib
# RUN mv /var/lib/apache-hbase-$BASE_VERSION-SNAPSHOT /var/lib/hbase/

RUN wget "https://dlcdn.apache.org/hbase/2.6.3/hbase-2.6.3-hadoop3-bin.tar.gz"
RUN tar -xvzf "hbase-2.6.3-hadoop3-bin.tar.gz" --directory=/var/lib
RUN mv /var/lib/hbase-2.6.3-hadoop3 /var/lib/hbase
RUN rm -f "hbase-2.6.3-hadoop3-bin.tar.gz"
RUN rm -rf /var/lib/hbase/conf
RUN mkdir -p /var/lib/hbase/logs
RUN chown -R hbase:hbase /var/lib/hbase

WORKDIR /
RUN rm -rf /var/lib/hbase_repo

ENV HBASE_HOME=/var/lib/hbase
ENV HBASE_CONF_DIR=/var/lib/hbase/conf
ENV PATH=$HBASE_HOME/bin:$PATH

WORKDIR /var/lib
RUN mkdir -p otel
WORKDIR /var/lib/otel
RUN wget "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/$OTEL_COLLECTOR_JAR_VERSION/opentelemetry-javaagent.jar"
RUN wget "https://github.com/open-telemetry/opentelemetry-java-contrib/releases/download/$OTEL_JMX_JAR_VERSION/opentelemetry-jmx-metrics.jar"
RUN chown -R hbase:hbase /var/lib/otel

WORKDIR /

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
