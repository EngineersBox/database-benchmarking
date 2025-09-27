import os, subprocess
from enum import Enum
from typing import Any, Callable, Optional 

def hdfsStartNameNode() -> None:
    commands = [
        "hadoop namenode -format",
        "hadoop-daemon.sh --config $HADOOP_HOME/etc/hadoop --script hdfs start namenode",
        "hdfs dfs -mkdir /user",
        "hdfs dfs -mkdir /tmp",
        "hdfs dfs -mkdir /tmp/hadoop-yarn",
        "hdfs dfs -mkdir /tmp/hadoop-yarn/staging",
        "hdfs dfs -chmod 1777 /tmp",
        "hdfs dfs -chmod 1777 /tmp/hadoop-yarn",
        "hdfs dfs -chmod 1777 /tmp/hadoop-yarn/staging",
    ]
    for command in commands:
        result = subprocess.run(command, shell=True, user="hadoop")
        result.check_returncode()

def hdfsStartDataNode() -> None:
	subprocess.run(
        "hadoop-daemon.sh --config $HADOOP_HOME/etc/hadoop --script hdfs start datanode",
        shell=True,
        user="hadoop"
    ).check_returncode()

def hdfsStartResourceManager() -> None:
    subprocess.run(
        "yarn-daemon.sh --config $HADOOP_HOME/etc/hadoop start resourcemanager",
        shell=True,
        user="hadoop"
    ).check_returncode()

def hdfsStartNodeManager() -> None:
	subprocess.run(
        "yarn-daemon.sh --config $HADOOP_HOME/etc/hadoop start nodemanager",
        shell=True,
        user="hadoop"
    ).check_returncode()

def hdfsStartWebProxy() -> None:
	subprocess.run(
        "yarn-daemon.sh --config $HADOOP_HOME/etc/hadoop start proxyserver",
        shell=True,
        user="hadoop"
    ).check_returncode()

def hdfsStartMapredHistory() -> None:
    subprocess.run(
        "mr-jobhistory-daemon.sh --config $HADOOP_HOME/etc/hadoop start historyserver",
        shell=True,
        user="hadoop"
    ).check_returncode()

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
        if (raw_role not in HBaseNodeRole._member_names_):
            raise RuntimeError(f"Unknown role specified in NODE_ROLES: {node_roles}")
        role = HBaseNodeRole[raw_role.upper()]
        init = role.initFunction()
        if (init != None):
            init()
