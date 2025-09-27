# NOTE: This file is named 'cass' and not 'cassandra' since
#       it will conflict with the cassandra-driver dependecy
#       which is also named 'cassandra' as a module.
import os, time, random, logging
from typing import Any
from cassandra.cluster import Cluster

logging.basicConfig(format="[%(levelname)s] %(name)s :: %(message)s", level=logging.DEBUG)

MAX_RETRIES=10

def constructReplication(config: dict[str, Any]) -> str:
    rf = ""
    for i in range(int(config["DC_COUNT"])):
        rf += f"\t'dc-{i}': {config["YCSB_RF"]},\n"
    return rf.removesuffix(",\n").removeprefix("\t")

def main(config: dict[str, Any]) -> None:
    retry_delay = 1
    for attempt in range(MAX_RETRIES):
        session = None
        try:
            logging.info("Connecting to Cassandra cluster [Attempt: %d/%d]", attempt + 1, MAX_RETRIES)
            cluster = Cluster(contact_points=config["NODE_IP"])
            session = cluster.connect()
            logging.info("Established connection to Cassandra cluster")
        except:
            logging.warning("Attempt failed, sleeping for %d seconds", retry_delay)
            time.sleep(retry_delay)
            retry_delay *= 2
            retry_delay += random.uniform(0, 1)
            continue
        logging.info("Creating YCSB keyspace")
        session.execute(f"""create keyspace ycsb with replication = {{
            'class': 'NetworkTopologyStrategy',
            {constructReplication(config)}
        }};""")
        logging.info("Creating usertable in YCSB keyspace")
        session.execute(f"""create table ycsb.usertable (
            y_id varchar primary key,
            field0 varchar,
            field1 varchar,
            field2 varchar,
            field3 varchar,
            field4 varchar,
            field5 varchar,
            field6 varchar,
            field7 varchar,
            field8 varchar,
            field9 varchar
        ) with compaction = {{
            'class': 'UnifiedCompactionStrategy',
            'scaling_parameters': 'T4',
            'target_sstable_size': '1GiB'
        }}
        and memtable = 'trie';""")
        return
    raise ConnectionRefusedError(f"Exceeded max retries ({MAX_RETRIES}) attempting to connect to Cassandra cluster")
