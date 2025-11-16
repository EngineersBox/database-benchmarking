FROM ghcr.io/engineersbox/otel-lgtm:latest
LABEL org.opencontainers.image.source https://github.com/EngineersBox/cassandra-benchmarking

ARG OTEL_JMX_JAR_VERSION=v1.35.0

RUN yum install -y java-17-openjdk wget
RUN echo 'export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")' >> ~/.bashrc

RUN mkdir -p /var/lib/otel
WORKDIR /var/lib/otel
RUN wget "https://github.com/open-telemetry/opentelemetry-java-contrib/releases/download/$OTEL_JMX_JAR_VERSION/opentelemetry-jmx-metrics.jar"

COPY scripts/otel/run-otelcol.sh /otel-lgtm/run-otelcol.sh
WORKDIR /otel-lgtm
