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
    logging.info(f"Command: {command}")
    stdout_text = result.stdout.decode()
    if (len(stdout_text) == 0):
        stdout_text = "N/A"
    stderr_text = result.stderr.decode()
    if (len(stderr_text) == 0):
        stderr_text = "N/A"
    if (result.returncode != 0):
        logging.error(f"Failed to run command\n\tSTDOUT: {stdout_text}\n\tSTDERR: {stderr_text}")
        result.check_returncode()
    logging.info(f"Result\n\tSTDOUT: {stdout_text}\n\tSTDERR: {stderr_text}")

def hdfsStartNameNode() -> None:
    commands = [
        "sudo $HADOOP_HOME/bin/hdfs namenode -format",
        "sudo $HADOOP_HOME/bin/hdfs --config $HADOOP_HOME/etc/hadoop --daemon start namenode",
        "sudo $HADOOP_HOME/bin/hdfs dfs -mkdir /user",
        "sudo $HADOOP_HOME/bin/hdfs dfs -mkdir /hbase",
    # NOTE: These sudo executed hdfs commands cause the HDFS filesystem to be
    #        root owned and thus when HBase goes to write to them, it fails.
    #        The /hbase dir should be owned by the hbase user (1000:1000)
        "sudo $HADOOP_HOME/bin/hdfs dfs -chown 1000:1000 /hbase",
        "sudo $HADOOP_HOME/bin/hdfs dfs -chmod 0777 /hbase",
        "sudo $HADOOP_HOME/bin/hdfs dfs -mkdir /tmp",
        "sudo $HADOOP_HOME/bin/hdfs dfs -mkdir /tmp/hadoop-yarn",
        "sudo $HADOOP_HOME/bin/hdfs dfs -mkdir /tmp/hadoop-yarn/staging",
        "sudo $HADOOP_HOME/bin/hdfs dfs -chmod 1777 /tmp",
        "sudo $HADOOP_HOME/bin/hdfs dfs -chmod 1777 /tmp/hadoop-yarn",
        "sudo $HADOOP_HOME/bin/hdfs dfs -chmod 1777 /tmp/hadoop-yarn/staging",
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

def hbaseZookeeperInit() -> None:
    runCommand("sudo mkdir -p /var/lib/cluster/zookeeper && sudo chmod 0777 /var/lib/cluster/zookeeper")

class HBaseAppType(Enum):
    HDFS = "hdfs"
    HBase = "hbase"

class HBaseNodeRole(Enum):
    HBASE_DATA = None, HBaseAppType.HBase
    HBASE_ZOOKEEPER = hbaseZookeeperInit, HBaseAppType.HBase
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
