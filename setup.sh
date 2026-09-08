#!/bin/bash

cd "$(dirname "$0")"

usage() {
    echo "Usage: setup.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --nginx       Run base setup and configure nginx"
    echo "  --nginx-only  Configure nginx only (skip base setup)"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "With no options, runs base setup only."
    exit 0
}

NGINX=false
NGINX_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --nginx) NGINX=true ;;
        --nginx-only) NGINX_ONLY=true ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $arg"; usage ;;
    esac
done

configure_nginx() {
    read -p "Site name (e.g. example): " sitename
    read -p "Domain name (e.g. example.com): " domain

    sed -e "s/example\.com/$domain/g" \
        -e "s|/var/www/example|/var/www/$sitename|g" \
        ./etc/nginx/server-block > /etc/nginx/sites-available/$sitename

    mkdir -p /var/www/$sitename
    ln -sf /etc/nginx/sites-available/$sitename /etc/nginx/sites-enabled/$sitename
    systemctl reload nginx

    read -p "Run certbot? [y/N] " confirm
    [[ "$confirm" == [yY] ]] && certbot --nginx
}

if $NGINX_ONLY; then
    configure_nginx
    exit 0
fi

# confirm public SSH key has been copied over
if [[ ! -s ~/.ssh/authorized_keys ]]; then
    echo "No SSH keys found in ~/.ssh/authorized_keys"
    echo "From your local machine, run: ssh-copy-id root@<server>"
    exit 1
fi

# drop in ssh overrides
mkdir -p /etc/ssh/sshd_config.d
cp ./etc/ssh/overrides.conf /etc/ssh/sshd_config.d/overrides.conf
systemctl reload sshd

# update firewall
ufw allow ssh
ufw allow http
ufw allow https
ufw enable

# optionally set hostname
read -p "New hostname (blank to skip): " hostname
[[ -n "$hostname" ]] && hostnamectl set-hostname "$hostname"

# prevent cloud-init from resetting hostname on reboot
mkdir -p /etc/cloud/cloud.cfg.d
echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99_hostname.cfg

# update and upgrade packages
apt update && apt upgrade -y

# install packages
apt install -y nginx certbot python3-certbot-nginx rsync vim ranger bat fail2ban

if $NGINX; then
    configure_nginx
fi

# limit systemd journal size
mkdir -p /etc/systemd/journald.conf.d
cp ./etc/journald/maxuse.conf /etc/systemd/journald.conf.d/maxuse.conf
systemctl restart systemd-journald

# update configs
mkdir -p $HOME/.config
cp -r ./dotfiles/. $HOME/.config/
mv $HOME/.config/bashrc $HOME/.bashrc

read -p "Reboot now? [y/N] " confirm
[[ "$confirm" == [yY] ]] && reboot
