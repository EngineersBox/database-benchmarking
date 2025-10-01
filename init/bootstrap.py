import json, logging, subprocess
from typing import Any
from enum import Enum

def cassandraPreInit(_: dict[str, Any]) -> None:
    logging.debug("No pre-init stage for Cassandra, skipping")

def cassandraPostInit(config: dict[str, Any]) -> None:
    invokeInit = config["INVOKE_INIT"] or False
    if (not invokeInit):
        return
    import app.cass as cass
    cass.postInit(config)

def elasticsearchPreInit(_: dict[str, Any]) -> None:
    logging.debug("No pre-init stage for Elasticsearch, skipping")

def elasticsearchPostInit(_: dict[str, Any]) -> None:
    logging.debug("No post-init stage for Elasticsearch, skipping")

def hbasePreInit(config: dict[str, Any]) -> None:
    import app.hbase as hbase
    hbase.main(config)

def hbasePostInit(_: dict[str, Any]) -> None:
    logging.debug("No post-init stage for HBase, skipping")

def mongoDBPreInit(_: dict[str, Any]) -> None:
    logging.debug("No pre-init stage for MongoDB, skipping")

def mongoDBPostInit(_: dict[str, Any]) -> None:
    logging.debug("No post-init stage for MongoDB, skipping")

def scyllaPreInit(_: dict[str, Any]) -> None:
    logging.debug("No pre-init stage for Scylla, skipping")

def scyllaPostInit(_: dict[str, Any]) -> None:
    logging.debug("No post-init stage for Scylla, skipping")

def otelPreInit(config: dict[str, Any]) -> None:
    import app.otel as otel
    otel.main(config)

def otelPostInit(_: dict[str, Any]) -> None:
    logging.debug("No post-init stage for OTEL, skipping")

class ApplicationVariant(Enum):
    CASSANDRA = cassandraPreInit, cassandraPostInit
    ELASTICSEARCH = elasticsearchPreInit, elasticsearchPostInit
    HBASE = hbasePreInit, hbasePostInit
    MONGO_DB = mongoDBPreInit, mongoDBPostInit
    SCYLLA = scyllaPreInit, scyllaPostInit
    OTEL_COLLECTOR = otelPreInit, otelPostInit

    def invokePreInit(self, config: dict[str, Any]) -> None:
        self.value[0](config)

    def invokePostInit(self, config: dict[str, Any]) -> None:
        self.value[1](config)

logging.basicConfig(format="[%(levelname)s] %(name)s :: %(message)s", level=logging.DEBUG)

CONFIG_PATH = "/var/lib/cluster/init/bootstrap_config.json"

def main() -> None:
    with open(CONFIG_PATH, 'r') as f:
        config = json.load(f)
    variant = str(config["APPLICATION_VARIANT"])
    application = ApplicationVariant.__members__[variant.upper()]
    logging.info(f"Invoking {variant} pre-init stage")
    application.invokePreInit(config)
    logging.info(f"Starting {variant} services")
    try:
        subprocess.run(
            f"docker compose -f /var/lib/cluster/docker/{variant}/docker-compose.yaml up -d",
            shell=True
        ).check_returncode()
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to start {variant} docker compose services")
        raise e
    logging.info(f"Invoking {variant} post-init stage")
    application.invokePostInit(config)
    logging.info("Node bootstrap succeeded")

if __name__ == "__main__":
    main()
