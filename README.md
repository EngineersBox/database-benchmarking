# cassandra-benchmarking

Cassandra Benchmarking Utilities

## Build

### Cassandra

In order to create a cassandra image, run the following

```bash
docker build -t ghcr.io/engineersbox/cassandra:5.0 -f docker/instance/cassandra.dockerfile .
```

You can optionally supply a repo and commit-ish marker to build from:

* `--build-arg="REPOSITORY=<repo>"` defaulting to <https://github.com/engineersbox/cassandra>
* `--build-arg="COMMIT_ISH=<commit | branch | tag>"` defaulting to `cassandra-5.0`
* `--build-arg="UID=<cassandra user uid>"` defaulting to `1000`
* `--build-arg="GID=<casasndra group id>"` defaulting to `1000`
* `--build-arg="OTEL_COLLECTOR_JAR_VERSION=<version>"` defaulting to `v2.2.0`
* `--build-arg="OTEL_JMX_JAR_VERSION=<version>"` defaulting to `v1.32.0`

The image can then be pushed to the GitHub container repository

```bash
docker push ghcr.io/engineersbox/cassandra:5.0
```

### HBase

You'll need to create a `settings.xml` file to use with the following contents to configure the maven's access to the GitHub repo for Kairos. Make sure to fill out the `USER` and `TOKEN` templates:

> ![NOTE]
> The `settings.xml` file in the image is removed after the hbase build has completed.
> This ensures that no credentials are persisted in the image itself.

```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">

    <activeProfiles>
        <activeProfile>gh-kairos</activeProfile>
    </activeProfiles>

    <profiles>
        <profile>
            <id>gh-kairos</id>
            <repositories>
                <repository>
                    <id>central</id>
                    <url>https://repo.maven.apache.org/maven2</url>
                </repository>
                <repository>
                    <id>gh-kairos</id>
                    <url>https://maven.pkg.github.com/engineersbox/kairos</url>
                    <snapshots>
                        <enabled>true</enabled>
                    </snapshots>
                </repository>
            </repositories>
        </profile>
    </profiles>

    <servers>
        <server>
            <id>gh-kairos</id>
            <username>USER</username>
            <password>TOKEN</password>
        </server>
    </servers>
</settings>
```

Then build the image via:

```bash
docker build -t ghcr.io/engineersbox/hbase:2.6.3-kairos -f docker/hbase/hbase.dockerfile .
```

You can optionally supply a repo and commit-ish marker to build from:

* `--build-arg="REPOSITORY=<repo>"` defaulting to <https://github.com/engineersbox/hbase>
* `--build-arg="COMMIT_ISH=<commit | branch | tag>"` defaulting to `2.6.3-kairos`
* `--build-arg="UID=<hbase user uid>"` defaulting to `1000`
* `--build-arg="GID=<hbase group id>"` defaulting to `1000`
* `--build-arg="OTEL_COLLECTOR_JAR_VERSION=<version>"` defaulting to `v2.2.0`
* `--build-arg="OTEL_JMX_JAR_VERSION=<version>"` defaulting to `v1.32.0`
* `--build-arg="M2_SETTINGS_PATH=<host relative path>"` defaulting to `settings.xml`

The image can then be pushed to the GitHub container repository

```bash
docker push ghcr.io/engineersbox/hbase:2.6.3-kairos
```

## OpenTelemetry Collector

```bash
docker build -t ghcr.io/engineersbox/otel-collector:latest -f docker/collector/otel.dockerfile .
```

* `--build-arg="OTEL_JMX_JAR_VERSION=<version>"` defaulting to `v1.32.0`

```bash
docker push ghcr.io/engineersbox/otel-collector:latest
```

## Startup

### Configuration

1. Ensure you set the values of any templates within the following config files:
    * `config/otel/otel-collector.properties`
    * `config/otel/otel-collector-config.yaml`
    * `config/otel/otel-instance.properties`
    * `config/otel/otel-instance-config.yaml`
    * `docker/instance/.env`
2. Choose any additional appropriate configurations for Cassandra within the `config/cassandra`
directory.
3. This repo relies on the `vmprobe` utility, so make sure that is installed with your favourite
package manager.
4. Set up the desired keyspace and table mappings for metrics to be collected in `config/otel/jmx/jmx.groovy`
in the last part of the `__instrumentCassandra()` function.
5. Ensure you use the `scripts/apply_iptables_rules.sh` script to set up the required port access
between servers if you are using a remote configuration.
6. Configure the RMI server host in `config/cassandra/cassandra-env.sh` according to the isntructions in 
the template parameter

### Casandra

Starting cassandra is straightforward, it requires the usage of the following and a parameter
denoting whether to remove all data and flush page cache. It can also be supplimented with
additional arguments to the `docker run` command.

```bash
sudo ./scripts/run_cassandra.sh <refresh: y|n>
```

### OpenTelemetry Collector

Similarly for the OTEL collector with:

```bash
sudo ./scripts/run_otel.sh <refresh: y|n>
```

## Remote Access

Deploying the collector or cassandra on a remote instance will require you to access the services
by forwarding the relevant port to your local machine via SSH (if it is not publically visible).

```bash
ssh -L <port>:localhost:<port> <remote instance>
```

## User Permissions

Using a normal docker configuration (not rootless) is simple to set user permissions for. Make sure
that any files and directories mounted into `cassandra` container are owned as `1000:1000` for the
`uid:gid` bits.

### Rootless Docker

Assuming that you have the container user congiured as `1000:1000` and your user on the host mapped
as `<user>:100000:65536` in both `/etc/subuid` and `/etc/subgid`, then you will need ensure that any
directories/files mounted into the container used by the cassandra user are owned by `100999:100999`.

The reason for this is that the mapping will move any host users from 0 to 100000 up by 100000. As such
a host uid:gid binding of `1000:1000` corresponds to `100999:100999`. To do this, just run the following
over anything you intend to mount into the Cassandra container:

```bash
sudo chmod -R 100999:100999 <path>
```

## Collector

![OTEL, Loki, Prometheus, Tempo, Grafana](./docs/otel_lgtm.png)
