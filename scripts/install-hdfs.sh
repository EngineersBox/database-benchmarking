#!/usr/bin/env bash

set -x

VERSION="$1"

sudo apt-get update -y
sudo apt-get install -y \
    default-jdk \
    zlib1g-dev \
    pkg-config \
    libssl-dev \
    libsasl2-dev \
    bzip2 \
    libbz2-dev \
    libjansson-dev \
    fuse \
    zstd \
    pdsh \
    tree \
    openssh-server \
    openssh-client

# Create hadoop user and setup inter-node SSH
sudo adduser hadoop
sudo usermod -aG sudo hadoop
# sudo -u hadoop ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
# sudo -u hadoop chmod 700 ~/.ssh
# sudo -u hadoop chmod 600 ~/.ssh/authorized_keys
# echo "ssh" | sudo tee -a /etc/pdsh/rcmd_default > /dev/null

# Create the HDFS mount if necessary
# if test -b /dev/sdb && ! grep -q /dev/sdb /etc/fstab; then
#     sudo mke2fs -F -j /dev/sdb
#     sudo mount /dev/sdb /mnt
#     sudo chmod 755 /mnt
#     echo "/dev/sdb      /mnt    ext3    defaults,nofail 0       2" | sudo tee -a /etc/fstab > /dev/null
# fi

# sudo mkdir /mnt/hadoop
# sudo chmod 1777 /mnt/hadoop

# Pull hadoop release
sudo wget "https://downloads.apache.org/hadoop/common/hadoop-$VERSION/hadoop-$VERSION-lean.tar.gz"
sudo tar -xzf "hadoop-$VERSION-lean.tar.gz"
sudo mv "hadoop-$VERSION" /var/lib/hadoop
sudo chmod 0777 /var/lib/hadoop
mkdir -p /var/lib/hadoop/logs /var/lib/hadoop/logs/yarn

# Copy in config overrides
sudo cp -r /var/lib/cluster/config/hadoop/etc/hadoop/* /var/lib/hadoop/etc/hadoop/.

# Construct and configure hadoop properties
java_home=$(readlink -f /usr/bin/javac | sed "s:bin/javac::")
sudo sed -i "s%@@JAVA_HOME@@%$java_home%g" /var/lib/hadoop/etc/hadoop/hadoop-env.sh

# Ensure the hadoop user owns everything
sudo chown -R hadoop:hadoop /var/lib/hadoop

# Create directories for data
sudo mkdir -p /home/hadoop/hdfs/{name,data,namesecondary}
sudo chown -R hadoop:hadoop /home/hadoop/hdfs

cat << EOF | sudo tee -a /home/hadoop/.bashrc /home/hadoop/.hadoop_env
export HADOOP_HOME=/var/lib/hadoop
export HADOOP_INSTALL=\$HADOOP_HOME
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
export HADOOP_OPTS="-Djava.library.path=\$HADOOP_HOME/lib/native"
export JAVA_HOME=$java_home
EOF
sudo chown hadoop:hadoop /home/hadoop/.hadoop_env

# Install javax activation
sudo wget "https://jcenter.bintray.com/javax/activation/javax.activation-api/1.2.0/javax.activation-api-1.2.0.jar" -O /var/lib/hadoop/lib/javax.activation-api-1.2.0.jar
