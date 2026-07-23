#!/bin/bash

# SET THESE VARIABLES FIRST

set -e

sudo apt update -y
sudo apt upgrade -y
sudo apt install git curl build-essential ca-certificates -y

curl -LO https://go.dev/dl/go1.25.12.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.25.12.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
source ~/.bashrc
go version

go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
CGO_ENABLED=1 xcaddy build --with github.com/corazawaf/coraza-caddy/v2 --with github.com/corazawaf/coraza-coreruleset
sudo mv caddy /usr/local/bin/caddy
sudo chmod +x /usr/local/bin/caddy
caddy version

if [ -d /etc/caddy/coraza ]; then
	sudo rm -rf /etc/caddy/
fi
sudo mkdir -p /etc/caddy/coraza
cd /etc/caddy/coraza
sudo git clone https://github.com/corazawaf/coraza-coreruleset.git
sudo git clone https://github.com/coreruleset/coreruleset.git crs
cd crs
sudo cp crs-setup.conf.example crs-setup.conf
sudo tee /etc/caddy/Caddyfile > /dev/null << 'EOF'
{
	order coraza_waf first
}
:80 {
	coraza_waf {
		load_owasp_crs
		directives `
			Include @coraza.conf-recommended
			Include @crs-setup.conf.example
			Include @owasp_crs/*.conf
			SecRuleEngine On
		`
	}
	reverse_proxy 127.0.0.1:3000
}
EOF

curl https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm install 24
nvm use 24

cd ~
git clone https://github.com/juice-shop/juice-shop
cd juice-shop
npm install && npm run build
sudo tee /etc/systemd/system/juiceshop.service > /dev/null << 'EOF'
[Unit]
Description=OWASP Juice Shop
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/juice-shop
ExecStart=$(which node) build/app.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/caddy.service > /dev/null << 'EOF'
[Unit]
Description=Caddy
After=network.target juiceshop.service

[Service]
User=root
ExecStart=/usr/local/bin/caddy run --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable juiceshop caddy

echo "Automated installation complete"
echo "System will restart in 15sec"
sleep 15
reboot