import json, logging, subprocess
from typing import Any, Optional
from enum import Enum

logging.basicConfig(format="[%(levelname)s] %(name)s :: %(message)s", level=logging.DEBUG)

class HBaseAppType(Enum):
    HDFS = "hdfs"
    HBase = "hbase"

class HBaseNodeRole(Enum):
    HBASE_DATA = "hbase_data", None, HBaseAppType.HBase
    HBASE_ZOOKEEPER = "hbase_zookeeper", "zookeeper", HBaseAppType.HBase
    HBASE_MASTER = "hbase_master", "master", HBaseAppType.HBase
    HBASE_BACKUP_MASTER = "hbase_backup_master", "backupmaster", HBaseAppType.HBase
    HDFS_NAME = "hdfs_name", None, HBaseAppType.HDFS
    HDFS_DATA = "hdfs_data", None, HBaseAppType.HDFS
    HDFS_RESOURCE_MANAGER = "hdfs_resource_manager", None, HBaseAppType.HDFS
    HDFS_NODE_MANAGER = "hdfs_node_manager", None, HBaseAppType.HDFS,
    HDFS_WEB_PROXY = "hdfs_web_proxy", None, HBaseAppType.HDFS,
    HDFS_MAPRED_HISTORY = "hdfs_mapred_history", None, HBaseAppType.HDFS

    def __str__(self) -> str:
        return "%s" % self.value[0]

    def composeProfile(self) -> Optional[str]:
        return self.value[1]

    def appType(self) -> HBaseAppType:
        return self.value[2]

CONFIG_PATH = "/var/lib/cluster/init/bootstrap_config.json"

def dockerComposeUp(variant: str, profiles: list[str] = []) -> None:
    profiles_opt = ""
    if (len(profiles) > 0):
        profiles_opt = "--profile ".join(profiles)
    try:
        subprocess.run(
            f"docker compose -f /var/lib/cluster/docker/{variant}/docker-compose.yaml {profiles_opt} up -d",
            shell=True
        ).check_returncode()
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to start {variant} docker compose services")
        raise e

def cassandraPostInit(config: dict[str, Any]) -> None:
    invokeInit = config["INVOKE_INIT"] or False
    if (not invokeInit):
        return
    import app.cass as cass
    cass.postInit(config)

def hbasePreInit(config: dict[str, Any]) -> None:
    import app.hbase as hbase
    hbase.main(config)

def hbaseStart(config: dict[str, Any]) -> None:
    roles = list(config["NODE_ROLES"])
    profiles = []
    for role in roles:
        upper_role = role.upper()
        if (role not in HBaseNodeRole.__members__):
            logging.error(f"Unknown role {role}, skipping")
            continue
        hbase_role = HBaseNodeRole.__members__[upper_role]
        compose_profile = hbase_role.composeProfile()
        if (compose_profile != None):
            profiles.append(compose_profile)
    dockerComposeUp("hbase", profiles)

def otelPreInit(config: dict[str, Any]) -> None:
    import app.otel as otel
    otel.main(config)

class ApplicationVariant(Enum):
    CASSANDRA = None, lambda _: dockerComposeUp("cassandra"), cassandraPostInit
    ELASTICSEARCH = None, lambda _: dockerComposeUp("elasticsearch"), None
    HBASE = hbasePreInit, hbaseStart, None
    MONGO_DB = None, lambda _: dockerComposeUp("mongodb"), None
    SCYLLA = None, lambda _: dockerComposeUp("scylla"), None
    OTEL_COLLECTOR = otelPreInit, lambda _: dockerComposeUp("otel"), None

    def invokePreInit(self, config: dict[str, Any]) -> None:
        pre_init_fn = self.value[0]
        if (pre_init_fn == None):
            logging.info(f"No pre-init stage for {self.name}, skipping")
            return;
        pre_init_fn(config)

    def invokeStart(self, config: dict[str, Any]) -> None:
        self.value[1](config)

    def invokePostInit(self, config: dict[str, Any]) -> None:
        post_init_fn = self.value[2]
        if (post_init_fn == None):
            logging.info(f"No post-init stage for {self.name}, skipping")
            return;
        post_init_fn(config)

def main() -> None:
    with open(CONFIG_PATH, 'r') as f:
        config = json.load(f)
    variant = str(config["APPLICATION_VARIANT"])
    application = ApplicationVariant.__members__[variant.upper()]
    logging.info(f"Invoking {variant} pre-init stage")
    application.invokePreInit(config)
    logging.info(f"Starting {variant} services")
    application.invokeStart(config)
    logging.info(f"Invoking {variant} post-init stage")
    application.invokePostInit(config)
    logging.info("Node bootstrap succeeded")

if __name__ == "__main__":
    main()
