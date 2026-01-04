#!/usr/bin/env bash

source /var/lib/cluster/scripts/logging.sh

init_logger --journal --tag node_setup

log_info "Overlaying etc/** scripts into node filesystem /etc"
sudo cp -r /var/lib/cluster/etc/** /etc/.
log_info "Ensuring consistent permissions on /etc/profile.d/10-utils.sh"
sudo chmod root:root /etc/profile.d/10-utils.sh

log_info "Updating and installing dependencies"
sudo apt-get update -y
sudo apt-get install -y python3-pip python3-venv
python3 -m pip install -r /var/lib/cluster/init/requirements.txt

log_info "Finished setup"
