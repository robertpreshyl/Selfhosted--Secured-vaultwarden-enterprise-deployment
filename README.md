# 🔐 Enterprise-Grade Self-Hosted Vaultwarden Password Manager

[![Security](https://img.shields.io/badge/Security-Hardened-success)](https://github.com)
[![Infrastructure](https://img.shields.io/badge/Infrastructure-Production-blue)](https://github.com)
[![Reverse Proxy](https://img.shields.io/badge/Reverse%20Proxy-Traefik-orange)](https://traefik.io)
[![Password Manager](https://img.shields.io/badge/Password%20Manager-Vaultwarden-green)](https://github.com/dani-garcia/vaultwarden)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

> **A comprehensive guide to deploying Vaultwarden password manager with enterprise-grade security, reverse proxy, and network isolation on existing VPN infrastructure**

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Key Features](#key-features)
- [Security Posture](#security-posture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Deployment](#detailed-deployment)
- [Security Hardening](#security-hardening)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

This repository documents a **production-grade deployment** of [Vaultwarden](https://github.com/dani-garcia/vaultwarden) (an unofficial Bitwarden-compatible server) with comprehensive security hardening on a VPS already running critical infrastructure services including:

- 🌐 **NetBird** - Mesh VPN for zero-trust networking
- 🔒 **WireGuard** - Fast and secure VPN tunnels  
- 🛡️ **OpenVPN** - Traditional VPN server with static IPs
- 🔐 **Vaultwarden** - Self-hosted password manager (NEW)

### Why This Matters for Security Professionals

As cybersecurity professionals, we understand that **password management is the foundation of organizational security**. This project demonstrates:

✅ **Zero-trust principles** - Network isolation and least-privilege access  
✅ **Defense in depth** - Multiple security layers (reverse proxy, firewall, IDS)  
✅ **Operational security** - Automated monitoring, logging, and alerting  
✅ **Infrastructure as Code** - Reproducible, auditable deployments  
✅ **Compliance ready** - Aligned with NIST, CIS, and ISO 27001 frameworks

---

## 🏗️ Architecture

### High-Level Infrastructure Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     INTERNET (0.0.0.0/0)                        │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        │        Oracle Cloud Firewall   │
        │         (Security Groups)      │
        │                │                │
        └────────────────┼────────────────┘
                         │
    ┌────────────────────┼────────────────────────────┐
    │                    │                            │
    │            OCI VPS (Ubuntu 24.04)               │
    │         IP: YOUR_VPS_IP                         │
    │                    │                            │
    │  ┌─────────────────┼─────────────────────────┐ │
    │  │       iptables + fail2ban Layer           │ │
    │  │  • Rate limiting (DDoS protection)        │ │
    │  │  • Brute-force prevention                 │ │
    │  │  • Trusted IP whitelisting                │ │
    │  └─────────────────┼─────────────────────────┘ │
    │                    │                            │
    │  ┌─────────────────┴─────────────────────────┐ │
    │  │                                            │ │
    │  │  ┌──────────────────────────────────────┐ │ │
    │  │  │   Traefik Reverse Proxy (v3.5.3)    │ │ │
    │  │  │   Ports: 8080 (HTTP), 8443 (HTTPS)  │ │ │
    │  │  │   • Automatic HTTPS (Let's Encrypt)  │ │ │
    │  │  │   • Cloudflare DNS-01 Challenge      │ │ │
    │  │  │   • Security headers                 │ │ │
    │  │  │   • Rate limiting                    │ │ │
    │  │  └──────────────┬───────────────────────┘ │ │
    │  │                 │                          │ │
    │  │  ┌──────────────┴───────────────────────┐ │ │
    │  │  │   Docker Network: traefik-public     │ │ │
    │  │  │   Subnet: 172.20.0.0/16              │ │ │
    │  │  │   (Isolated from NetBird)            │ │ │
    │  │  └──────────────┬───────────────────────┘ │ │
    │  │                 │                          │ │
    │  │  ┌──────────────┴───────────────────────┐ │ │
    │  │  │     Vaultwarden Container (v1.34.3) │ │ │
    │  │  │     • Argon2id password hashing     │ │ │
    │  │  │     • PBKDF2 600k iterations         │ │ │
    │  │  │     • Secure token authentication   │ │ │
    │  │  │     • Automated daily backups        │ │ │
    │  │  └──────────────────────────────────────┘ │ │
    │  │                                            │ │
    │  └────────────────────────────────────────────┘ │
    │                                                  │
    │  ┌────────────────────────────────────────────┐ │
    │  │   Existing NetBird Infrastructure          │ │
    │  │   Docker Network: ubuntu_netbird           │ │
    │  │   • Caddy (Ports 80, 443)                  │ │
    │  │   • Management, Signal, Relay              │ │
    │  │   • Coturn STUN/TURN                       │ │
    │  │   • WireGuard (Port 51820)                 │ │
    │  │   • OpenVPN (Port 1194)                    │ │
    │  └────────────────────────────────────────────┘ │
    │                                                  │
    └──────────────────────────────────────────────────┘
```

### Network Isolation Strategy

```
┌─────────────────────────────────────────────────┐
│         Docker Network Architecture             │
├─────────────────────────────────────────────────┤
│                                                 │
│  ubuntu_netbird (NetBird services)              │
│  ├─ Caddy (reverse proxy)                       │
│  ├─ Management API                              │
│  ├─ Signal server                               │
│  ├─ Relay server                                │
│  ├─ Coturn (STUN/TURN)                          │
│  └─ Zitadel (authentication)                    │
│                                                 │
│  traefik-public (Vaultwarden stack) ← ISOLATED  │
│  ├─ Traefik v3.5.3                              │
│  └─ Vaultwarden v1.34.3                         │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Zero interference** - Completely separate Docker networks ensure NetBird and Vaultwarden services don't conflict.

---

## ✨ Key Features

### 🔐 **Password Management**
- ✅ Self-hosted Bitwarden-compatible server (Vaultwarden)
- ✅ End-to-end encryption for all vault data
- ✅ Support for all Bitwarden clients (Web, Desktop, Mobile, Browser Extensions)
- ✅ Organization password sharing capabilities
- ✅ Two-factor authentication (2FA) support
- ✅ Secure password generation and auditing

### 🛡️ **Security Hardening**
- ✅ **Traefik reverse proxy** with automatic HTTPS (Let's Encrypt)
- ✅ **Cloudflare DNS-01 challenge** for wildcard certificates
- ✅ **fail2ban** with custom jails for SSH and Traefik authentication
- ✅ **iptables rate limiting** - DDoS protection while maintaining global VPN access
- ✅ **SSH hardening** - Key-only authentication, no root login, rate limiting
- ✅ **Argon2id password hashing** (524MB memory, 3 iterations, 4 parallelism)
- ✅ **Container security** - Non-privileged containers, no-new-privileges flag
- ✅ **Network isolation** - Separate Docker networks for service stacks

### 📊 **Monitoring & Operations**
- ✅ **Automated security monitoring** - Runs every 15 minutes via cron
- ✅ **Health checks** - Docker healthchecks for all containers
- ✅ **Automated backups** - Daily backups with 14-day retention
- ✅ **Comprehensive logging** - Security events, authentication failures, rate limits
- ✅ **Alert system** - Failed auth attempts, resource usage, container health

### 🌐 **Infrastructure Integration**
- ✅ **Zero disruption** to existing NetBird mesh VPN infrastructure
- ✅ **Compatible** with existing WireGuard and OpenVPN services
- ✅ **Global accessibility** for family/team members while maintaining security
- ✅ **Trusted IP whitelisting** - Home network bypasses rate limits

---

## 🔒 Security Posture

### Threat Model & Mitigation

| Threat | Mitigation | Status |
|--------|------------|--------|
| **Credential theft** | Argon2id hashing, secure token generation | ✅ Implemented |
| **Brute-force attacks** | fail2ban (3 attempts = 24h ban on SSH) | ✅ Active |
| **DDoS attacks** | iptables rate limiting (per-service limits) | ✅ Active |
| **Man-in-the-middle** | HTTPS only, HSTS headers, valid SSL certs | ✅ Enforced |
| **Unauthorized access** | SSH key-only, no root login, firewall rules | ✅ Hardened |
| **Service disruption** | Health monitoring, automated restarts | ✅ Monitored |
| **Data loss** | Daily automated backups (14-day retention) | ✅ Scheduled |
| **Container escape** | no-new-privileges, capability dropping | ✅ Applied |

### Compliance Frameworks

This deployment aligns with:
- ✅ **NIST Cybersecurity Framework** (Identify, Protect, Detect, Respond, Recover)
- ✅ **CIS Critical Security Controls** (Controls 1-20)
- ✅ **ISO 27001** Information Security Management principles
- ✅ **OWASP** Web Application Security best practices

### Security Metrics

**Before Security Hardening:**
- ❌ Admin credentials exposed
- ❌ API endpoints exposed to internet
- ⚠️ No brute-force protection
- ⚠️ No DDoS protection
- ❌ No security monitoring

**After Security Hardening:**
- ✅ Credentials regenerated with Argon2id
- ✅ APIs secured (localhost-only or rate-limited)
- ✅ fail2ban protecting all public services
- ✅ iptables rate limiting (22 rules active)
- ✅ Automated security monitoring (every 15 min)
- ✅ Zero service disruption achieved

---

## 📦 Prerequisites

### System Requirements

- **VPS/Server**: 
  - CPU: 2+ cores (ARM64 or x86_64)
  - RAM: 4GB minimum, **12GB recommended** for production
  - Disk: 50GB minimum, **100GB recommended** for growth
  - OS: Ubuntu 22.04+ or Debian 11+

- **Network**:
  - Public IP address
  - Ports available: 8080, 8443 (or custom ports)
  - Domain name with DNS control (for SSL certificates)

### Software Dependencies

```bash
# Required
- Docker Engine 24.0+
- Docker Compose v2.20+
- curl
- openssl
- git

# Recommended
- fail2ban
- iptables-persistent
- cron
```

### Services Already Running (Example)

This guide assumes you may have existing services like:
- NetBird mesh VPN
- WireGuard VPN
- OpenVPN server
- Caddy or other reverse proxy

**Our approach ensures zero interference with existing infrastructure.**

---

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/vaultwarden-secure-deployment.git
cd vaultwarden-secure-deployment
```

### 2. Configure Environment Variables

```bash
# Copy example environment files
cp configs/vaultwarden/vaultwarden.env.example configs/vaultwarden/vaultwarden.env
cp configs/traefik/.env.example configs/traefik/.env

# Edit with your values
nano configs/vaultwarden/vaultwarden.env
nano configs/traefik/.env
```

**Required variables:**
- `DOMAIN` - Your domain (e.g., vault.example.com)
- `ADMIN_TOKEN` - Generate with `openssl rand -base64 48`
- `CF_DNS_API_TOKEN` - Cloudflare API token (if using DNS-01 challenge)

### 3. Generate Secure Admin Token

```bash
# Generate random 64-character token
TOKEN=$(openssl rand -base64 48)

# Hash with Argon2id
echo -n "$TOKEN" | argon2 $(openssl rand -base64 32) -e -id -t 3 -m 524288 -p 4

# Save both - the token for your password manager, hash for vaultwarden.env
```

### 4. Deploy Traefik Reverse Proxy

```bash
cd /srv
mkdir -p traefik/{config,acme}

# Copy configs
cp ~/vaultwarden-secure-deployment/configs/traefik/* /srv/traefik/

# Set permissions for SSL certificates
chmod 600 /srv/traefik/acme/acme.json

# Start Traefik
docker-compose up -d
```

### 5. Deploy Vaultwarden

```bash
cd /srv
mkdir -p vaultwarden/data

# Copy configs
cp ~/vaultwarden-secure-deployment/configs/vaultwarden/* /srv/vaultwarden/

# Start Vaultwarden
docker-compose up -d
```

### 6. Verify Deployment

```bash
# Check container health
docker ps

# Test HTTPS access
curl -k https://your-domain.com:8443/

# Verify SSL certificate
openssl s_client -connect your-domain.com:8443 -servername your-domain.com
```

---

## 📚 Detailed Deployment

For comprehensive step-by-step instructions, see:

- 📖 [**Full Deployment Guide**](docs/DEPLOYMENT.md)
- 🔒 [**Security Hardening Guide**](docs/SECURITY_HARDENING.md)
- 🔧 [**Configuration Reference**](docs/CONFIGURATION.md)
- 🐛 [**Troubleshooting Guide**](docs/TROUBLESHOOTING.md)

---

## 🛡️ Security Hardening

### 1. SSH Hardening

```bash
# Run SSH hardening script
sudo bash scripts/ssh-hardening.sh

# Key changes:
# - PermitRootLogin no
# - PasswordAuthentication no
# - PubkeyAuthentication yes
# - MaxAuthTries 3
# - AllowUsers <your-user>
```

### 2. Install fail2ban

```bash
# Run fail2ban setup
sudo bash scripts/setup-fail2ban.sh

# Creates jails for:
# - SSH (3 attempts = 24h ban)
# - Traefik authentication (5 attempts = 1h ban)
# - Vaultwarden login (5 attempts = 1h ban)
```

### 3. Configure iptables Rate Limiting

```bash
# Run iptables security script
sudo bash scripts/iptables-security.sh

# Applies rate limiting to:
# - SSH: 4 connections/min
# - HTTP/HTTPS: 100 connections/sec
# - Vaultwarden: 50 connections/10sec
# - Management APIs: 30 connections/min
```

### 4. Enable Security Monitoring

```bash
# Install monitoring script
sudo cp scripts/security-monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/security-monitor.sh

# Add to crontab (runs every 15 minutes)
echo "*/15 * * * * /usr/local/bin/security-monitor.sh" | sudo crontab -
```

### 5. Validate Security

```bash
# Run comprehensive validation
sudo bash scripts/security-validation.sh

# Checks:
# - Container health
# - SSH hardening
# - fail2ban status
# - iptables rules
# - Service accessibility
```

---

## 📊 Monitoring & Maintenance

### Health Monitoring

**Automated checks every 15 minutes:**
- ✅ Failed SSH authentication attempts
- ✅ Docker container health status
- ✅ Disk space usage (alert at 85%)
- ✅ Memory usage (alert at 90%)
- ✅ fail2ban ban status
- ✅ Critical service availability

**Log locations:**
```bash
# Security monitoring logs
/var/log/security/monitor.log      # Monitoring output
/var/log/security/alerts.log       # Critical alerts

# fail2ban logs
/var/log/fail2ban.log              # Ban/unban events

# Container logs
docker logs vaultwarden            # Vaultwarden logs
docker logs traefik-vaultwarden    # Traefik logs
```

### Backup & Recovery

**Automated daily backups:**
```bash
# Vaultwarden data backup script
/usr/local/bin/vaultwarden-backup.sh

# Runs daily at 3:00 AM
# Retention: 14 days
# Location: /srv/vaultwarden/backups/
```

**Manual backup:**
```bash
# Backup Vaultwarden data
docker exec vaultwarden sqlite3 /data/db.sqlite3 ".backup '/data/backup.sqlite3'"
docker cp vaultwarden:/data/backup.sqlite3 ./vaultwarden-backup-$(date +%Y%m%d).sqlite3

# Backup configuration files
tar -czf config-backup-$(date +%Y%m%d).tar.gz \
  /srv/vaultwarden/vaultwarden.env \
  /srv/traefik/docker-compose.yml \
  /srv/traefik/config/
```

**Restore from backup:**
```bash
# Stop container
docker-compose down

# Restore database
docker cp ./vaultwarden-backup-YYYYMMDD.sqlite3 vaultwarden:/data/db.sqlite3

# Restart container
docker-compose up -d
```

### Updates

**Updating Vaultwarden:**
```bash
cd /srv/vaultwarden

# Backup first
docker exec vaultwarden sqlite3 /data/db.sqlite3 ".backup '/data/backup.sqlite3'"

# Pull latest image
docker-compose pull

# Recreate container
docker-compose up -d

# Verify
docker ps
docker logs vaultwarden
```

**Updating Traefik:**
```bash
cd /srv/traefik

# Update image version in docker-compose.yml
nano docker-compose.yml

# Recreate container
docker-compose up -d

# Verify
docker ps
docker logs traefik-vaultwarden
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Cannot Access Vaultwarden Web Interface

```bash
# Check container status
docker ps | grep vaultwarden

# Check logs
docker logs vaultwarden --tail 50

# Verify Traefik routing
docker logs traefik-vaultwarden --tail 50 | grep vaultwarden

# Test local access
curl -k https://localhost:8443/
```

#### 2. SSL Certificate Issues

```bash
# Check certificate status
docker exec traefik-vaultwarden cat /acme.json | jq

# Check Cloudflare API token
docker exec traefik-vaultwarden env | grep CF_DNS_API_TOKEN

# Force certificate renewal
docker restart traefik-vaultwarden
```

#### 3. fail2ban Not Blocking Attackers

```bash
# Check fail2ban status
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Check jail logs
sudo tail -f /var/log/fail2ban.log

# Manually ban IP
sudo fail2ban-client set sshd banip 192.168.1.100

# Manually unban IP
sudo fail2ban-client set sshd unbanip 192.168.1.100
```

#### 4. High Memory Usage

```bash
# Check system resources
free -h
docker stats

# Check largest containers
docker ps --format "table {{.Names}}\t{{.Size}}"

# Restart resource-heavy container
docker restart <container-name>
```

For more troubleshooting guides, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

---

## 📈 Performance Optimization

### Resource Usage (Production Metrics)

**System Specifications:**
- **VPS**: Oracle Cloud (ARM64)
- **CPU**: 4 vCPUs
- **RAM**: 12 GB
- **Disk**: 100 GB SSD

**Current Resource Utilization:**
```
Memory:  2.0 GB / 12 GB (17%)
Disk:    7.7 GB / 100 GB (8%)
```

**Container Resource Usage:**
- Traefik: ~50 MB RAM
- Vaultwarden: ~30 MB RAM
- NetBird stack: ~400 MB RAM (8 containers)

**Capacity for Growth:**
- ✅ Memory: 10 GB available (83% free)
- ✅ Disk: 92 GB available (92% free)
- ✅ Can easily support 1000+ vault users

---

## 🤝 Contributing

We welcome contributions from the cybersecurity and DevOps community!

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-security-improvement`
3. **Commit your changes**: `git commit -m 'Add comprehensive IDS integration'`
4. **Push to branch**: `git push origin feature/amazing-security-improvement`
5. **Open a Pull Request**

### Contribution Guidelines

- ✅ Follow security best practices
- ✅ Include documentation for new features
- ✅ Test on clean Ubuntu/Debian installation
- ✅ Redact any sensitive information (IPs, tokens, domains)
- ✅ Add to troubleshooting guide if relevant

### Areas for Contribution

- 🔐 Additional security hardening measures
- 📊 Enhanced monitoring and alerting
- 🐳 Docker security improvements
- 📝 Documentation improvements
- 🧪 Automated testing scripts
- 🌍 Multi-language support

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### Third-Party Licenses

- [Vaultwarden](https://github.com/dani-garcia/vaultwarden) - GPL-3.0 License
- [Traefik](https://github.com/traefik/traefik) - MIT License
- [fail2ban](https://github.com/fail2ban/fail2ban) - GPL-2.0 License

---

## 🙏 Acknowledgments

- **Vaultwarden Team** - For the amazing Bitwarden-compatible server
- **Traefik Labs** - For the powerful reverse proxy
- **NetBird Team** - For the mesh VPN solution
- **Docker Community** - For containerization technology
- **Cybersecurity Community** - For continuous security improvements

---

## 📞 Support & Contact

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/vaultwarden-secure-deployment/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/vaultwarden-secure-deployment/discussions)
- **Security**: Report security vulnerabilities privately via GitHub Security Advisory

---

## 🔖 Project Status

**Current Version**: 1.0.0  
**Status**: ✅ Production Ready  
**Last Updated**: October 26, 2025

### Roadmap

- [ ] Automated CI/CD pipeline for testing
- [ ] Ansible playbook for one-command deployment
- [ ] Kubernetes deployment manifests
- [ ] Integration with centralized SIEM
- [ ] Multi-region deployment guide
- [ ] High-availability setup documentation

---

## ⭐ Star History

If this project helped you secure your organization's password management infrastructure, please consider giving it a star! ⭐

---

<p align="center">
  <strong>Built with ❤️ for the Cybersecurity Community</strong><br>
  <em>Securing organizations, one password vault at a time</em>
</p>

<p align="center">
  <a href="#-table-of-contents">Back to Top ⬆️</a>
</p>
