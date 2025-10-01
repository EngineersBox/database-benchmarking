import subprocess, logging
from enum import Enum
from typing import Any, Callable, Optional 

logging.basicConfig(format="[%(levelname)s] %(name)s :: %(message)s", level=logging.DEBUG)

def runCommand(command: str, user: str = "hadoop") -> None:
    result = subprocess.run(
        f"sudo su -s /bin/bash -c 'source ~/.hadoop_env && {command}' - {user}",
        shell=True,
        user=user,
        stderr=subprocess.PIPE,
        stdout=subprocess.PIPE
    )
    if (result.returncode != 0):
        logging.error(f"Failed to run command: {result.stderr.decode()}")
        result.check_returncode()
    logging.info(f"Command: {command}\nResult: {result.stdout.decode()}")

def hdfsStartNameNode() -> None:
    commands = [
        "hadoop namenode -format",
        "hdfs --config $HADOOP_HOME/etc/hadoop --daemon start namenode",
        "hdfs dfs -mkdir /user",
        "hdfs dfs -mkdir /tmp",
        "hdfs dfs -mkdir /tmp/hadoop-yarn",
        "hdfs dfs -mkdir /tmp/hadoop-yarn/staging",
        "hdfs dfs -chmod 1777 /tmp",
        "hdfs dfs -chmod 1777 /tmp/hadoop-yarn",
        "hdfs dfs -chmod 1777 /tmp/hadoop-yarn/staging",
    ]
    for command in commands:
        runCommand(command)

def hdfsStartDataNode() -> None:
    runCommand("hdfs --config $HADOOP_HOME/etc/hadoop --daemon start datanode")

def hdfsStartResourceManager() -> None:
    runCommand("yarn-daemon.sh --config $HADOOP_HOME/etc/hadoop start resourcemanager")

def hdfsStartNodeManager() -> None:
    runCommand("yarn-daemon.sh --config $HADOOP_HOME/etc/hadoop start nodemanager")

def hdfsStartWebProxy() -> None:
    runCommand("yarn-daemon.sh --config $HADOOP_HOME/etc/hadoop start proxyserver")

def hdfsStartMapredHistory() -> None:
    runCommand("mr-jobhistory-daemon.sh --config $HADOOP_HOME/etc/hadoop start historyserver")

class HBaseAppType(Enum):
    HDFS = "hdfs"
    HBase = "hbase"

class HBaseNodeRole(Enum):
    HBASE_DATA = None, HBaseAppType.HBase
    HBASE_ZOOKEPER = None, HBaseAppType.HBase
    HBASE_MASTER = None, HBaseAppType.HBase
    HBASE_BACKUP_MASTER = None, HBaseAppType.HBase
    HDFS_NAME = hdfsStartNameNode, HBaseAppType.HDFS
    HDFS_DATA = hdfsStartDataNode, HBaseAppType.HDFS
    HDFS_RESOURCE_MANAGER = hdfsStartResourceManager, HBaseAppType.HDFS
    HDFS_NODE_MANAGER = hdfsStartNodeManager, HBaseAppType.HDFS,
    HDFS_WEB_PROXY = hdfsStartWebProxy, HBaseAppType.HDFS,
    HDFS_MAPRED_HISTORY = hdfsStartMapredHistory, HBaseAppType.HDFS

    def initFunction(self) -> Optional[Callable[[], None]]:
        return self.value[0]

    def appType(self) -> HBaseAppType:
        return self.value[1]

def main(config: dict[str, Any]):
    node_roles: list[str] = config["NODE_ROLES"]
    for raw_role in node_roles:
        upper_role = raw_role.strip().upper()
        if (upper_role not in HBaseNodeRole.__members__):
            member_names = [name for (name, _) in HBaseNodeRole.__members__]
            raise RuntimeError(f"Unknown role '{upper_role}' specified in NODE_ROLES: {member_names}")
        role = HBaseNodeRole[upper_role]
        init = role.initFunction()
        if (init != None):
            init()
