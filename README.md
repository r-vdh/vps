# VPS Setup

Basic setup scripts and config files for a new VPS.

## Files

| File | Destination |
|------|-------------|
| `dotfiles/bashrc` | `~/.bashrc` |
| `dotfiles/bash_alias` | `~/.config/bash_alias` |
| `dotfiles/bash_env` | `~/.config/bash_env` |
| `dotfiles/vim/vimrc` | `~/.config/vim/vimrc` |
| `etc/ssh/overrides.conf` | `/etc/ssh/sshd_config.d/overrides.conf` |
| `etc/journald/maxuse.conf` | `/etc/systemd/journald.conf.d/maxuse.conf` |
| `etc/nginx/server-block` | `/etc/nginx/sites-available/<sitename>` |

## DNS Setup

In your domain registrar's DNS settings, add the following records:

| Type | Host | Value |
|------|------|-------|
| A | `@` | `<IPv4>` |
| AAAA | `@` | `<IPv6>` |
| CNAME | `www` | `<domain>` |

## Automated Setup

If you don't already have an SSH key pair, generate one from your local machine:

```
ssh-keygen -t ed25519
```

Then copy your public key to the server:

```
ssh-copy-id root@example.com
```

Then run `setup.sh` as root:

```
bash setup.sh              # base setup only
bash setup.sh --nginx      # base setup + nginx config
bash setup.sh --nginx-only # nginx config only (if base setup already done)
bash setup.sh -h           # show help
```

The rest of this README is the manual equivalent if you'd rather do it step by step.

---

## Manual Instructions

### 1. Copy SSH Key (from local machine)

If you don't already have an SSH key pair, generate one:

```
ssh-keygen -t ed25519
```

Then copy your public key to the server:

```
ssh-copy-id root@example.com
```

### 2. Disable Password Authentication

Copy `etc/ssh/overrides.conf` to `/etc/ssh/sshd_config.d/overrides.conf`:

```
PasswordAuthentication no
UsePAM no
```

Then reload sshd:

```
systemctl reload sshd
```

### 3. Configure Firewall

```
ufw allow ssh
ufw allow http
ufw allow https
ufw enable
```

### 4. Set Hostname (optional)

```
hostnamectl set-hostname <newhostname>
```

### 5. Prevent cloud-init from Resetting Hostname

*Vultr's cloud-init will revert the hostname on reboot unless you do this.*

Create `/etc/cloud/cloud.cfg.d/99_hostname.cfg`:

```
preserve_hostname: true
```

### 6. Vultr IPv6 Reverse DNS

In the Vultr control panel: **Settings > IPv6 > Reverse DNS**

- IP: your IPv6 address
- Reverse DNS: example.com

### 7. Update Packages

```
apt update
apt upgrade
```

### 8. Install Packages

```
apt install nginx certbot python3-certbot-nginx rsync vim ranger bat fail2ban
```

### 9. Configure nginx (optional)

Copy `etc/nginx/server-block` to `/etc/nginx/sites-available/<sitename>` and update the domain and web root paths inside it.

Create the web root directory:

```
mkdir /var/www/<sitename>
```

Symlink into sites-enabled:

```
ln -s /etc/nginx/sites-available/<sitename> /etc/nginx/sites-enabled/<sitename>
```

Reload nginx:

```
systemctl reload nginx
```

### 10. Run Certbot

*Say yes when asked about redirecting HTTP to HTTPS.*

```
certbot --nginx
```

### 11. Limit systemd Journal Size

Create `/etc/systemd/journald.conf.d/maxuse.conf`:

```
[Journal]
SystemMaxUse=200M
```

Restart the journal daemon:

```
systemctl restart systemd-journald
```

To clear existing bloat:

```
journalctl --vacuum-size=200M
```

### 12. Copy Dotfiles

```
mkdir -p ~/.config
cp -r ./dotfiles/. ~/.config/
mv ~/.config/bashrc ~/.bashrc
```

---

## Optional

*The following are not included in `setup.sh`.*

### Swap

Allocates disk space as overflow when RAM is exhausted.

```
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

### Unattended Upgrades

Automatically installs security updates.

```
apt install unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades
```

### Adding a User

```
useradd -m -G <groups> <username>
passwd <username>
```
