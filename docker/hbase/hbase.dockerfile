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

WORKDIR /var/lib
RUN git clone "$REPOSITORY" hbase_repo

WORKDIR /var/lib/hbase_repo
RUN git checkout "$BRANCH"
RUN if [ "x$COMMIT" != "x" ]; then git checkout "$COMMIT"; fi

# Maven settings for auth to repos
COPY ["$M2_SETTINGS_PATH", "/opt/.m2/"]

# Build the artifacts
RUN mvn -s /opt/.m2/settings.xml -DskipTests -Dhadoop.profile=3.0 clean install
RUN mvn -s /opt/.m2/settings.xml -DskipTests -Dhadoop.profile=3.0 package assembly:single

# Remove maven settings to avoid caching creds in image
RUN rm -f /opt/.m2/settings.xml

RUN mkdir -p /var/lib/hbase
RUN find /var/lib/hbase_repo/hbase-assembly/target -iname '*.tar.gz' -not -iname '*client*' \
    | head -n 1 \
    | xargs -I{} tar xzf {} --strip-components 1 -C /var/lib/hbase

# RUN wget "https://dlcdn.apache.org/hbase/2.6.3/hbase-2.6.3-hadoop3-bin.tar.gz"
# RUN tar -xvzf "hbase-2.6.3-hadoop3-bin.tar.gz" --directory=/var/lib
# RUN mv /var/lib/hbase-2.6.3-hadoop3 /var/lib/hbase
# RUN rm -f "hbase-2.6.3-hadoop3-bin.tar.gz"

RUN rm -rf /var/lib/hbase/conf
RUN mkdir -p /var/lib/hbase/logs
RUN chown -R hbase:hbase /var/lib/hbase

WORKDIR /var/lib/hbase/lib/kairos
# RUN wget https://repo1.maven.org/maven2/org/slf4j/slf4j-api/2.0.17/slf4j-api-2.0.17.jar
# RUN wget https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.33/slf4j-api-1.7.33.jar
# RUN wget https://repo1.maven.org/maven2/org/slf4j/jcl-over-slf4j/1.7.33/jcl-over-slf4j-1.7.33.jar
# RUN wget https://repo1.maven.org/maven2/org/slf4j/jul-to-slf4j/1.7.33/jul-to-slf4j-1.7.33.jar
# RUN wget https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-1.2-api/2.17.2/log4j-1.2-api-2.17.2.jar
# RUN wget https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-api/2.17.2/log4j-api-2.17.2.jar 
# RUN wget https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/2.17.2/log4j-core-2.17.2.jar
# RUN wget https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-slf4j-impl/2.17.2/log4j-slf4j-impl-2.17.2.jar
# RUN wget https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-api/2.25.2/log4j-api-2.25.2.jar 
# RUN wget https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/2.25.2/log4j-core-2.25.2.jar
# RUN wget https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-slf4j2-impl/2.25.2/log4j-slf4j2-impl-2.25.2.jar

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
COPY docker/hbase/start.sh /var/lib/hbase/bin/start.sh
COPY docker/hbase/start-daemons.sh /var/lib/hbase/bin/start-daemons.sh

USER hbase
# 16000: HMaster
# 16010: HMaster info web UI
# 16020: RegionServer
# 16030: RegionServer
# 16100: Multicast status
# 8080: REST server
# 8085: REST server web UI
# 9090: Thrift server
# 9095: Thrift server
# 2181: Zookeeper
# 2888: Zookeeper peer port
# 3888: Zookeeper leader election
# EXPOSE 16000 16010 16020 16030 16100 8080 8085 9090 9095 2181 2888 3888
# CMD ["/var/lib/hbase/bin/start.sh"]
