# Complete Deployment Guide

This comprehensive guide walks you through deploying Vaultwarden with Traefik reverse proxy and enterprise-grade security hardening.

## Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Phase 1: Infrastructure Preparation](#phase-1-infrastructure-preparation)
- [Phase 2: Traefik Deployment](#phase-2-traefik-deployment)
- [Phase 3: Vaultwarden Deployment](#phase-3-vaultwarden-deployment)
- [Phase 4: Security Hardening](#phase-4-security-hardening)
- [Phase 5: Validation & Testing](#phase-5-validation--testing)

---

## Pre-Deployment Checklist

Before beginning deployment, ensure you have:

### ✅ System Requirements
- [ ] Ubuntu 22.04+ or Debian 11+ server
- [ ] Minimum 4GB RAM (12GB recommended)
- [ ] Minimum 50GB disk (100GB recommended)
- [ ] Root or sudo access
- [ ] Public IP address

### ✅ Network Requirements
- [ ] Domain name purchased and configured
- [ ] DNS provider API access (for automated SSL)
- [ ] Firewall ports available (8080, 8443, or custom)
- [ ] No port conflicts with existing services

### ✅ Prerequisites Installed
- [ ] Docker Engine (24.0+)
- [ ] Docker Compose v2 (2.20+)
- [ ] curl, wget, git installed
- [ ] openssl for token generation

### ✅ Accounts & Access
- [ ] Cloudflare account (for DNS-01 challenge) OR
- [ ] Alternative DNS provider with API support
- [ ] Email account for SSL certificate notifications
- [ ] Password manager for storing generated credentials

---

## Phase 1: Infrastructure Preparation

### Step 1.1: Update System

```bash
# Update package lists and upgrade system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    curl \
    wget \
    git \
    openssl \
    ca-certificates \
    gnupg \
    lsb-release \
    apache2-utils
```

### Step 1.2: Install Docker

```bash
# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

### Step 1.3: Configure Docker (Optional but Recommended)

```bash
# Add your user to docker group (to avoid using sudo)
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
# Or run: newgrp docker

# Configure Docker logging
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart Docker
sudo systemctl restart docker
```

### Step 1.4: Create Project Structure

```bash
# Create directories
sudo mkdir -p /srv/{traefik,vaultwarden}
sudo mkdir -p /srv/traefik/{config,acme}
sudo mkdir -p /srv/vaultwarden/{data,backups}

# Set permissions
sudo chown -R $USER:$USER /srv/traefik /srv/vaultwarden
```

---

## Phase 2: Traefik Deployment

### Step 2.1: Configure DNS Records

Add DNS A records pointing to your VPS IP:

```
A    traefik.example.com    →    YOUR_VPS_IP
A    vault.example.com      →    YOUR_VPS_IP
```

### Step 2.2: Generate Cloudflare API Token

1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. Permissions: **Zone** → **DNS** → **Edit**
5. Zone Resources: **Include** → **All zones** (or specific zone)
6. Save token securely

### Step 2.3: Generate Traefik Dashboard Credentials

```bash
# Generate bcrypt password hash
echo $(htpasswd -nB admin) | sed -e s/\\$/\\$\\$/g

# Output will be something like:
# admin:$$2y$$05$$...hash...
# Save this for later
```

### Step 2.4: Create Traefik Configuration Files

```bash
cd /srv/traefik

# Copy example configurations from repo
cp ~/vaultwarden-secure-deployment/configs/traefik/docker-compose.yml.example docker-compose.yml
cp ~/vaultwarden-secure-deployment/configs/traefik/.env.example .env
cp ~/vaultwarden-secure-deployment/configs/traefik/config/traefik.yml config/
cp ~/vaultwarden-secure-deployment/configs/traefik/config/security.yml config/

# Edit environment file
nano .env
```

**Edit `.env` with your values:**
```env
CF_DNS_API_TOKEN=your_cloudflare_token_here
TRAEFIK_DASHBOARD_AUTH=admin:$$2y$$05$$...your_bcrypt_hash...
TRAEFIK_DOMAIN=traefik.example.com
VAULTWARDEN_DOMAIN=vault.example.com
LETSENCRYPT_EMAIL=admin@example.com
```

**Edit `docker-compose.yml`:**
- Replace `traefik.example.com` with your actual domain
- Verify port mappings (8080, 8443, 8081)
- Ensure network name is `traefik-public`

### Step 2.5: Prepare SSL Certificate Storage

```bash
# Create acme.json file with correct permissions
touch acme/acme.json
chmod 600 acme/acme.json
```

### Step 2.6: Start Traefik

```bash
cd /srv/traefik

# Start Traefik
docker compose up -d

# Verify it's running
docker ps | grep traefik

# Check logs
docker logs traefik-vaultwarden -f
```

### Step 2.7: Verify Traefik Dashboard

```bash
# Test dashboard access (should see login prompt)
curl -k https://traefik.example.com:8443/dashboard/

# Check SSL certificate
openssl s_client -connect traefik.example.com:8443 \
    -servername traefik.example.com 2>/dev/null | \
    grep -A 2 "Verify return code"
```

**Access dashboard:**
- URL: `https://traefik.example.com:8443/dashboard/`
- Username: `admin`
- Password: (your unhashed password)

---

## Phase 3: Vaultwarden Deployment

### Step 3.1: Generate Secure Admin Token

```bash
# Generate 64-character random token
TOKEN=$(openssl rand -base64 48)

# Display the token (SAVE THIS IN PASSWORD MANAGER!)
echo "Admin Token (save this): $TOKEN"

# Generate Argon2id hash
echo -n "$TOKEN" | argon2 $(openssl rand -base64 32) -e -id -t 3 -m 524288 -p 4

# Output will be: $argon2id$v=19$m=524288,t=3,p=4$...hash...
# This hash goes into vaultwarden.env
```

**IMPORTANT:** 
- Save the plain text token in your password manager
- You'll need it to access the admin panel
- The token is shown only once!

### Step 3.2: Create Vaultwarden Configuration

```bash
cd /srv/vaultwarden

# Copy example configurations
cp ~/vaultwarden-secure-deployment/configs/vaultwarden/docker-compose.yml.example docker-compose.yml
cp ~/vaultwarden-secure-deployment/configs/vaultwarden/vaultwarden.env.example vaultwarden.env

# Edit environment file
nano vaultwarden.env
```

**Edit `vaultwarden.env`:**
```env
# Your domain
DOMAIN=https://vault.example.com:8443

# Your Argon2 hashed token
ADMIN_TOKEN=$argon2id$v=19$m=524288,t=3,p=4$...YOUR_HASH_HERE...

# Security settings
SIGNUPS_ALLOWED=false
SHOW_PASSWORD_HINT=false
PASSWORD_ITERATIONS=600000
```

**Edit `docker-compose.yml`:**
- Replace `vault.example.com` with your actual domain
- Verify network is `traefik-public`
- Ensure Traefik labels are correct

### Step 3.3: Start Vaultwarden

```bash
cd /srv/vaultwarden

# Start Vaultwarden
docker compose up -d

# Verify it's running
docker ps | grep vaultwarden

# Check logs
docker logs vaultwarden -f
```

### Step 3.4: Verify Vaultwarden Access

```bash
# Test web interface
curl -k https://vault.example.com:8443/

# Check health
docker exec vaultwarden wget -qO- http://localhost/alive
```

**Access Vaultwarden:**
- Web Vault: `https://vault.example.com:8443/`
- Admin Panel: `https://vault.example.com:8443/admin/`
- Admin Token: (use plain text token from Step 3.1)

### Step 3.5: Initial Configuration

1. **Access Admin Panel:**
   - Go to: `https://vault.example.com:8443/admin/`
   - Enter your admin token

2. **Disable Public Signups:**
   - Already disabled in `vaultwarden.env`
   - Verify in admin panel: General Settings → Allow new signups → ❌

3. **Create Your Admin User:**
   - Go to main vault: `https://vault.example.com:8443/`
   - Click "Create Account"
   - Use strong master password (recommend 20+ characters)
   - Save master password in secure location

4. **Configure SMTP (Optional):**
   - In admin panel: SMTP Settings
   - Configure email server for notifications
   - Test with: Send Test Email

---

## Phase 4: Security Hardening

### Step 4.1: SSH Hardening

```bash
# Backup current SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-$(date +%Y%m%d)

# Create hardening configuration
sudo tee /etc/ssh/sshd_config.d/hardening.conf > /dev/null <<EOF
# SSH Hardening Configuration
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
AllowUsers YOUR_USERNAME
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
MaxStartups 10:30:60
EOF

# Test configuration
sudo sshd -t

# If no errors, restart SSH
sudo systemctl restart ssh

# IMPORTANT: Test new connection in separate terminal before closing current session!
```

### Step 4.2: Install and Configure fail2ban

```bash
# Install fail2ban
sudo apt install -y fail2ban

# Create jail configuration
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
destemail = admin@example.com
sendername = Fail2Ban-VPS
action = %(action_mwl)s
ignoreip = 127.0.0.1/8 ::1
         YOUR_HOME_IP/32

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h

[traefik-auth]
enabled = true
port = 8443
filter = traefik-auth
logpath = /var/log/traefik/access.log
maxretry = 5
findtime = 10m
bantime = 1h
EOF

# Create Traefik filter
sudo tee /etc/fail2ban/filter.d/traefik-auth.conf > /dev/null <<EOF
[Definition]
failregex = ^<HOST> - .* "(GET|POST|HEAD) .* HTTP/.*" 401
ignoreregex =
EOF

# Start fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Verify status
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

### Step 4.3: Configure iptables Rate Limiting

```bash
# Run the iptables security script
sudo bash ~/vaultwarden-secure-deployment/scripts/iptables-security.sh

# Verify rules applied
sudo iptables -L INPUT -n -v --line-numbers | less

# Save rules
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

### Step 4.4: Enable Security Monitoring

```bash
# Copy monitoring script
sudo cp ~/vaultwarden-secure-deployment/scripts/security-monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/security-monitor.sh

# Add to crontab
echo "*/15 * * * * /usr/local/bin/security-monitor.sh" | sudo crontab -

# Verify cron job
sudo crontab -l
```

---

## Phase 5: Validation & Testing

### Step 5.1: Run Security Validation

```bash
# Run comprehensive validation
sudo bash ~/vaultwarden-secure-deployment/scripts/security-validation.sh
```

### Step 5.2: Test All Services

```bash
# Check all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test Traefik
curl -k https://traefik.example.com:8443/dashboard/

# Test Vaultwarden
curl -k https://vault.example.com:8443/

# Check SSL certificates
echo | openssl s_client -connect vault.example.com:8443 -servername vault.example.com 2>/dev/null | \
    openssl x509 -noout -dates
```

### Step 5.3: Test Bitwarden Clients

1. **Web Vault:**
   - URL: `https://vault.example.com:8443/`
   - Login with your account
   - Create test entry

2. **Desktop Client:**
   - Download from: https://bitwarden.com/download/
   - Settings → Self-hosted → `https://vault.example.com:8443`
   - Login and sync

3. **Mobile App:**
   - iOS/Android: Install Bitwarden app
   - Settings → Self-hosted
   - Server URL: `https://vault.example.com:8443`
   - Login and test

4. **Browser Extension:**
   - Chrome/Firefox: Install Bitwarden extension
   - Settings → Self-hosted
   - Server URL: `https://vault.example.com:8443`
   - Login and autofill test

### Step 5.4: Verify Security Measures

```bash
# Check fail2ban is active
sudo fail2ban-client status

# Check iptables rules
sudo iptables -L TRUSTED_WHITELIST -n -v

# Check security logs
cat /var/log/security/monitor.log

# Verify backups
ls -lh /srv/vaultwarden/backups/
```

---

## Post-Deployment Checklist

After successful deployment, ensure:

- [ ] All containers are healthy (`docker ps`)
- [ ] SSL certificates are valid
- [ ] Traefik dashboard accessible
- [ ] Vaultwarden web vault accessible
- [ ] Admin panel accessible with token
- [ ] fail2ban protecting services
- [ ] iptables rate limiting active
- [ ] Security monitoring scheduled
- [ ] Backups configured and tested
- [ ] All Bitwarden clients tested
- [ ] Documentation updated with specifics
- [ ] Credentials stored securely

---

## Next Steps

1. **Configure Backup Strategy** - See [Backup Guide](BACKUP.md)
2. **Set Up Monitoring** - See [Monitoring Guide](MONITORING.md)
3. **Review Security** - See [Security Hardening Guide](SECURITY_HARDENING.md)
4. **Plan Updates** - See [Maintenance Guide](MAINTENANCE.md)

---

## Troubleshooting

If you encounter issues during deployment, see:
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Common Issues](COMMON_ISSUES.md)
- [FAQ](FAQ.md)

---

**Deployment Complete!** 🎉

Your enterprise-grade Vaultwarden password manager is now running with comprehensive security hardening.
