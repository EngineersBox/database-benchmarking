#!/usr/bin/env bash

source /var/lib/cluster/scripts/logging.sh
init_logger --journal --tag node_setup

set -o errexit -o pipefail -o noclobber

log_info "Overlaying etc/** scripts into node filesystem /etc"
sudo cp -r /var/lib/cluster/etc/** /etc/.
log_info "Ensuring consistent permissions on /etc/profile.d/10-utils.sh"
sudo chown root:root /etc/profile.d/10-utils.sh

log_info "Creating private SSH key"
mkdir -p ~/.ssh
geni-get key > ~/.ssh/id_rsa
sudo chmod 600 ~/.ssh/id_rsa
log_info "Creating public SSH key and marking as authorized"
sudo ssh-keygen -y -f ~/.ssh/id_rsa | sudo tee ~/.ssh/id_rsa.pub | sudo tee -a ~/.ssh/authorized_keys > /dev/null
sudo chmod 644 ~/.ssh/authorized_keys 

log_info "Updating and installing dependencies"
sudo apt-get update -y
sudo apt-get install -y \
    python3-pip \
    python3-venv \
    maven

log_info "Creating venv for bootstrap"
pushd /var/lib/cluster/init
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r /var/lib/cluster/init/requirements.txt

log_info "Invoking bootstrap service"
python3 bootstrap.py
popd

log_info "Finished setup"
