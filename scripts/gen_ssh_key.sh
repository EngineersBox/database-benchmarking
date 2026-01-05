#!/usr/bin/env bash

mkdir -p ~/.ssh
geni-get key > ~/.ssh/id_rsa
sudo chmod 600 ~/.ssh/id_rsa
sudo ssh-keygen -y -f ~/.ssh/id_rsa | sudo tee ~/.ssh/id_rsa.pub | sudo tee -a ~/.ssh/authorized_keys > /dev/null
sudo chmod 644 ~/.ssh/authorized_keys 
