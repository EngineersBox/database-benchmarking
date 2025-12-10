#!/usr/bin/env bash

echo "[INFO] Overlaying etc/** scripts into node filesystem /etc"
sudo cp -r /var/lib/cluster/etc/** /etc/.

echo "[INFO] Updating and installing dependencies"
sudo apt-get update -y
sudo apt-get install -y python3-pip python3-venv
python3 -m pip install -r /var/lib/cluster/init/requirements.txt

echo "[INFO] Finished setup"
