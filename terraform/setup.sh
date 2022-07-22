#!/bin/bash

if [ $# -ne 5 ]; then
  echo "usage: $(basename "$0") caddy_public_address rockserve_local_port prometheus_local_port prometheus_user prometheus_password"
  exit 1
fi

publicaddr=$1
rockserveport=$2
promport=$3
promuser=$4
prompass=$5

promurl="https://github.com/prometheus/prometheus/releases/download/v2.37.0/prometheus-2.37.0.linux-amd64.tar.gz"


# -----------------------------------------------------------------------------
# rockserve
# -----------------------------------------------------------------------------
echo "Installing rockserve"
sudo groupadd --system rockserve
sudo useradd --system \
  --gid rockserve \
  --shell /usr/sbin/nologin \
  --comment "RockBLOCK webhook server" \
  rockserve
# curl -L -o rockserve https://github.com/ctberthiaume/rockserve/releases/latest/download/rockserve.linux-amd64
# Assume binary is in home as "rockserve", either from curl or terraform file
# provisioner
sudo chmod +x rockserve
sudo cp rockserve /usr/local/bin/rockserve

cat << EOF | sudo tee /etc/systemd/system/rockserve.service
# rockserve.service
#
# For the rockserve RockBLOCK webhook server
#

[Unit]
Description=rockserve
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=exec
User=rockserve
Group=rockserve
ExecStart=/usr/local/bin/rockserve --address ":$rockserveport" --prometheus
TimeoutStopSec=5s
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now rockserve


# -----------------------------------------------------------------------------
# Prometheus
# -----------------------------------------------------------------------------
echo "Installing Prometheus"
sudo groupadd --system prometheus
sudo useradd --system \
  --gid prometheus \
  --create-home \
  --home-dir /var/lib/prometheus \
  --shell /usr/sbin/nologin \
  --comment "Prometheus monitoring tool" \
  prometheus
sudo mkdir /etc/prometheus

cat << EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval:     15s # By default, scrape targets every 15 seconds.

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:$promport']

  - job_name: 'pipecyte'
    static_configs:
      - targets: ['localhost:$rockserveport']

remote_write:
- url: https://prometheus-prod-10-prod-us-central-0.grafana.net/api/prom/push
  basic_auth:
    username: ${promuser}
    password: ${prompass}
EOF

curl -L -o prometheus.tar.gz "$promurl"
tar -zxf prometheus.tar.gz
sudo cp prometheus-*/prometheus prometheus-*/promtool /usr/local/bin/
sudo cp -r prometheus-*/consoles /etc/prometheus
sudo cp -r prometheus-*/console_libraries /etc/prometheus

sudo chown -R /etc/prometheus prometheus

cat << EOF | sudo tee /etc/systemd/system/prometheus.service
# prometheus.service
#
# For Prometheus monitoring
#

[Unit]
Description=Prometheus
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=exec
User=prometheus
Group=prometheus
WorkingDirectory=/var/lib/prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path /var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.enable-lifecycle
ExecReload=/usr/bin/curl -s -XPOST localhost:${promport}/-/reload
TimeoutStopSec=5s
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus


# -----------------------------------------------------------------------------
# Caddy
# -----------------------------------------------------------------------------
# https://caddyserver.com/docs/install#debian-ubuntu-raspbian
echo "Install caddy"
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy libnss3-tools

# caddy doesn't have permission to install its root cert. Must run this as root
# to install, making sure to use caddy's home directory.
# https://github.com/caddyserver/caddy/issues/4248
sudo HOME=~caddy caddy trust

echo "Install Caddyfile and reload daemon"
cat << EOF | sudo tee /etc/caddy/Caddyfile
${publicaddr}:80 {
	handle_path /message {
		rewrite * /message
		reverse_proxy localhost:8080
	}
	handle_path /* {
		respond 403
	}
}
EOF
sudo caddy fmt -overwrite /etc/caddy/Caddyfile
sudo systemctl restart caddy
