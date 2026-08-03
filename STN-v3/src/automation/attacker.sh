#!/bin/bash

# Script only for attacker setup
# To run the actual attack simulation, run the downloaded Metasploit module

set -e

sudo apt update -y
sudo apt upgrade -y

wget https://raw.githubusercontent.com/Ryo-Soikutsu/Secure-The-Network/refs/heads/main/STN-v3/src/automation/stn-attacker.rb
