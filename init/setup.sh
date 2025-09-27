#!/usr/bin/env bash

echo "[INFO] Updating and installing dependencies"
sudo apt-get update -y
sudo apt-get install -y python3-venv
python3 -m pip install -r requirements.txt

ehco "[INFO] Finished setup"
