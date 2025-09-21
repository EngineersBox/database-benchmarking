#!/usr/bin/env bash

VERSION="$1"

sudo apt-get update -y
sudo apt-get install -y \
    openjdk-8-jdk \
    zlib1g-dev \
    pkg-config \
    libssl-dev \
    libsasl2-dev \
    snappy \
    libsnappy-dev \
    bzip2 \
    libbz2-dev \
    libjansson-dev \
    fuse \
    lib-fuse \
    zstd \
    pdsh \
    tree \
    openssh-server \
    openssh-client

echo "ssh" | sudo tee /etc/pdsh/rcmd_default

sudo adduser hadoop
sudo usermod -aG sudo hadoop
sudo su - hadoop

ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa

sudo mkfs.ext4 /dev/sda4
sudo mount /dev/sda4 /tmp
sudo chmod 777 /tmp

wget "https://downloads.apache.org/hadoop/common/hadoop-$VERSION/hadoop-$VERSION.tar.gz"
tar -xvzf "hadoop-$VERSION.tar.gz"
sudo mv "hadoop-$VERSION" /var/lib/hadoop
sudo mkdir /var/lib/hadoop/logs

sudo chown -R hadoop:hadoop /var/lib/hadoop

cat >> ~/.bashrc << EOF
export HADOOP_HOME=/var/lib/hadoop
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"
EOF
