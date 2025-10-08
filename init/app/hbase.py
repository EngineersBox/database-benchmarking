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
        logging.error(f"Failed to run command\n STDOUT: {result.stdout.decode()}\nSTDERR: {result.stderr.decode()}")
        result.check_returncode()
    logging.info(f"Command: {command}\nResult: {result.stdout.decode()}")

def hdfsStartNameNode() -> None:
    commands = [
        "sudo $HADOOP_HOME/bin/hadoop namenode -format",
        "sudo $HADOOP_HOME/bin/hdfs --config $HADOOP_HOME/etc/hadoop --daemon start namenode",
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
    runCommand("sudo $HADOOP_HOME/bin/hdfs --config $HADOOP_HOME/etc/hadoop --daemon start datanode")

def hdfsStartResourceManager() -> None:
    runCommand("sudo $HADOOP_HOME/bin/yarn --config $HADOOP_HOME/etc/hadoop --daemon start resourcemanager")

def hdfsStartNodeManager() -> None:
    runCommand("sudo $HADOOP_HOME/bin/yarn --config $HADOOP_HOME/etc/hadoop --daemon start nodemanager")

def hdfsStartWebProxy() -> None:
    runCommand("sudo $HADOOP_HOME/bin/yarn --config $HADOOP_HOME/etc/hadoop --daemon start proxyserver")

def hdfsStartMapredHistory() -> None:
    runCommand("sudo $HADOOP_HOME/bin/mapred --config $HADOOP_HOME/etc/hadoop --daemon start historyserver")

class HBaseAppType(Enum):
    HDFS = "hdfs"
    HBase = "hbase"

class HBaseNodeRole(Enum):
    HBASE_DATA = None, HBaseAppType.HBase
    HBASE_ZOOKEEPER = None, HBaseAppType.HBase
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
    member_names = list(HBaseNodeRole.__members__.keys())
    for raw_role in node_roles:
        upper_role = raw_role.upper()
        if (upper_role not in member_names):
            raise RuntimeError(f"Unknown role '{upper_role}' specified in NODE_ROLES: {member_names}")
        role = HBaseNodeRole[upper_role]
        initFn = role.initFunction()
        if (initFn != None):
            initFn()
