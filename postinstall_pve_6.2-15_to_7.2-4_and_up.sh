#!/usr/bin/env bash
###CONFIGURATE CORE SYSTEM###
#disable enterprise repo
sed -i 's+deb https://enterprise.proxmox.com/debian/pve bullseye pve-enterprise+#deb https://enterprise.proxmox.com/debian/pve bullseye pve-enterprise+g' /etc/apt/sources.list.d/pve-enterprise.list
echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" >> /etc/apt/sources.list
apt update && apt upgrade -y

#configure sshd.conf
sed -i 's+#port 22/port 32000+g' /etc/ssh/sshd_config

###INSTALL REQUIRED SOFTWARE###
#persistent iptables
apt-get install iptables-persistent -y

#install fail2ban
apt-get install fail2ban -y

#darkmode for proxmox
bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh ) install

###CONFIGURE REQUIRED SOFTWARE##
#route default ui port 8006 to 443 and save configuration
iptables -t nat -I PREROUTING -i vmbr0 --dst 192.168.0.16  -p tcp --dport 443 -j REDIRECT --to-ports 8006
/usr/sbin/netfilter-persistent save

#create fail2ban configuration for ssh and proxmox ui
touch /etc/fail2ban/jail.d/bruteforce.conf
cat >> /etc/fail2ban/jail.d/bruteforce.conf <<EOL
[sshd]
enabled   = true
ignoreip  = 192.168.0.0/16
port      = 32000,22 
bantime   = 100y
banaction = %(banaction_allports)s
findtime  = 1d
maxretry  = 3
[proxmox]
enabled   = true
ignoreip  = 192.168.0.0/16
logpath   = /var/log/daemon.log
port      = https,http,8006 
bantime   = 100y
banaction = %(banaction_allports)s
findtime  = 1d
maxretry  = 3
EOL
touch /etc/fail2ban/filter.d/proxmox.conf
cat >> /etc/fail2ban/filter.d/proxmox.conf <<EOL
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOL
systemctl restart fail2ban
