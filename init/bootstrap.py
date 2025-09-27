import json, logging, subprocess
from typing import Any
from enum import Enum

def cassandraPreInit(config: dict[str, Any]) -> None:
    pass

def cassandraPostInit(config: dict[str, Any]) -> None:
    invokeInit = config["INVOKE_INIT"] or False
    if (not invokeInit):
        return
    import app.cass as cass
    cass.main(config)

def elasticsearchPreInit(config: dict[str, Any]) -> None:
    pass

def elasticsearchPostInit(config: dict[str, Any]) -> None:
    pass

def hbasePreInit(config: dict[str, Any]) -> None:
    pass

def hbasePostInit(config: dict[str, Any]) -> None:
    import app.hbase as hbase
    hbase.main(config)

def mongoDBPreInit(config: dict[str, Any]) -> None:
    pass

def mongoDBPostInit(config: dict[str, Any]) -> None:
    pass

def scyllaPreInit(config: dict[str, Any]) -> None:
    pass

def scyllaPostInit(config: dict[str, Any]) -> None:
    pass

def otelPreInit(config: dict[str, Any]) -> None:
    import app.otel as otel
    otel.main(config)

def otelPostInit(config: dict[str, Any]) -> None:
    pass

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
    subprocess.run(
        f"docker compose -f /var/lib/cluster/docker/{variant}/docker-compose.yaml up -d",
        shell=True
    ).check_returncode()
    logging.info(f"Invoking {variant} post-init stage")
    application.invokePostInit(config)

if __name__ == "__main__":
    main()
