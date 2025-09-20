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
