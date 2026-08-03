#!/bin/bash

# Set exit on first error
set -e 
echo "Updating server packages..."
sudo apt update -y
sudo apt upgrade -y

echo "Installing Docker Engine..."
sudo apt install ca-certificates curl git -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources << EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo $"${UBUNTU_CODENAME:-$VERSION_CODENAME}")
COmponents: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update -y
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo systemctl start docker && sudo systemctl enable docker
echo "Docker Engine & Compose installed successfully!"

echo "Installing Wazuh..."
echo "For ease of setup, using quickstart local installation"
echo "For more information: https://documentation.wazuh.com/current/quickstart.html"

curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && sudo bash ./wazuh-install.sh -a
sudo sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/wazuh.list