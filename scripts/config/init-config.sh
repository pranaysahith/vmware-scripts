#!/bin/bash
# defining vars
DEBIAN_FRONTEND=noninteractive
KERNEL_BOOT_LINE='net.ifnames=0 biosdevname=0'

# sudo without password prompt
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER >/dev/null

# update packages
sudo apt update && sudo apt upgrade -y

# install needed packages
sudo apt install -y telnet tcpdump open-vm-tools net-tools dialog curl git sed grep

# switching to predictable network interfaces naming
grep "$KERNEL_BOOT_LINE" /etc/default/grub >/dev/null || sudo sed -Ei "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 $KERNEL_BOOT_LINE\"/g" /etc/default/grub
sudo update-grub

# cloning vmware scripts repo
git clone --single-branch -b main https://github.com/k8-proxy/vmware-scripts.git ~/scripts

# installing the wizard
sudo install -T ~/scripts/scripts/wizard/wizard.sh /usr/local/bin/wizard -m 0755

# installing initconfig ( for running wizard on reboot )
sudo cp -f ~/scripts/scripts/bootscript/initconfig.service /etc/systemd/system/initconfig.service
sudo install -T ~/scripts/scripts/bootscript/initconfig.sh /usr/local/bin/initconfig.sh -m 0755
sudo systemctl daemon-reload

# enable initconfig for the next reboot
sudo systemctl enable initconfig

# install node exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz -qO- | tar xz -C /tmp/ 
sudo install -T /tmp/node_exporter-1.0.1.linux-amd64/node_exporter /usr/local/bin/node_exporter -m 0755
sudo ln -s /usr/local/bin/node_exporter /usr/sbin/node_exporter

# create node exporter user
sudo useradd node_exporter -s /sbin/nologin

# create node exporter service
sudo cp ~/scripts/visuallog/monitoring-scripts/node_exporter.service /etc/systemd/system/node_exporter.service
sudo mkdir -p /etc/prometheus

# install node exporter configuration
sudo cp ~/scripts/visuallog/monitoring-scripts/node_exporter.config /etc/prometheus/node_exporter.config
sudo systemctl daemon-reload

# start and enable node_exporter service
sudo systemctl enable --now node_exporter

# remove vmware scripts directory
rm -rf ~/scripts/
