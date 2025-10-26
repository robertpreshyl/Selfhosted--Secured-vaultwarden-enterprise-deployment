#!/bin/bash
#
# VPS Security Monitoring Script
# Checks for security events and logs alerts
# Run via cron every 15 minutes
#

LOG_FILE="/var/log/security/monitor.log"
ALERT_FILE="/var/log/security/alerts.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Create log files if they don't exist
touch "$LOG_FILE" "$ALERT_FILE"

echo "=== Security Monitor Run: $TIMESTAMP ===" >> "$LOG_FILE"

# 1. Check for failed SSH authentication attempts (last 15 minutes)
AUTH_FAILURES=$(journalctl -u ssh --since "15 minutes ago" 2>/dev/null | grep -i "failed\|failure" | wc -l)
if [ $AUTH_FAILURES -gt 10 ]; then
    echo "[$TIMESTAMP] WARNING - $AUTH_FAILURES failed SSH auth attempts in last 15 minutes" | tee -a "$ALERT_FILE" >> "$LOG_FILE"
    journalctl -u ssh --since "15 minutes ago" | grep -i "failed\|failure" | tail -5 >> "$LOG_FILE"
fi

# 2. Check for unauthorized sudo usage
SUDO_USAGE=$(journalctl --since "15 minutes ago" | grep "sudo.*COMMAND=" | wc -l)
if [ $SUDO_USAGE -gt 50 ]; then
    echo "[$TIMESTAMP] WARNING - High sudo usage detected: $SUDO_USAGE commands in 15 minutes" | tee -a "$ALERT_FILE" >> "$LOG_FILE"
fi

# 3. Check Docker container health
UNHEALTHY=$(docker ps --filter "health=unhealthy" -q 2>/dev/null | wc -l)
if [ $UNHEALTHY -gt 0 ]; then
    echo "[$TIMESTAMP] CRITICAL - $UNHEALTHY unhealthy containers detected" | tee -a "$ALERT_FILE" >> "$LOG_FILE"
    docker ps --filter "health=unhealthy" --format "  Container: {{.Names}} - Status: {{.Status}}" >> "$LOG_FILE"
fi

# 4. Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "[$TIMESTAMP] WARNING - Disk usage at ${DISK_USAGE}%" | tee -a "$ALERT_FILE" >> "$LOG_FILE"
fi

# 5. Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [ $MEM_USAGE -gt 90 ]; then
    echo "[$TIMESTAMP] WARNING - Memory usage at ${MEM_USAGE}%" | tee -a "$ALERT_FILE" >> "$LOG_FILE"
fi

# 6. Check fail2ban status
if command -v fail2ban-client &> /dev/null; then
    FAIL2BAN_STATUS=$(fail2ban-client status 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "[$TIMESTAMP] CRITICAL - fail2ban is not running" | tee -a "$ALERT_FILE" >> "$LOG_FILE"
    else
        # Check SSH jail
        SSH_BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
        if [ ! -z "$SSH_BANNED" ] && [ $SSH_BANNED -gt 0 ]; then
            echo "[$TIMESTAMP] INFO - fail2ban currently blocking $SSH_BANNED IPs on SSH" >> "$LOG_FILE"
        fi
        
        # Check Traefik jail
        TRAEFIK_BANNED=$(fail2ban-client status traefik-auth 2>/dev/null | grep "Currently banned" | awk '{print $4}')
        if [ ! -z "$TRAEFIK_BANNED" ] && [ $TRAEFIK_BANNED -gt 0 ]; then
            echo "[$TIMESTAMP] INFO - fail2ban currently blocking $TRAEFIK_BANNED IPs on Traefik" >> "$LOG_FILE"
        fi
    fi
fi

# 7. Check for iptables blocks (rate limiting triggers)
IPTABLES_BLOCKS=$(journalctl --since "15 minutes ago" | grep -E "SSH_BRUTE_FORCE|TRAEFIK_FLOOD" | wc -l)
if [ $IPTABLES_BLOCKS -gt 0 ]; then
    echo "[$TIMESTAMP] INFO - $IPTABLES_BLOCKS iptables rate limit blocks in last 15 minutes" >> "$LOG_FILE"
    journalctl --since "15 minutes ago" | grep -E "SSH_BRUTE_FORCE|TRAEFIK_FLOOD" | tail -3 >> "$LOG_FILE"
fi

# 8. Check critical service status
SERVICES=("docker" "fail2ban" "ssh" "openvpn-server@server")
for SERVICE in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        true  # Service is running, no action needed
    else
        if systemctl list-units --all --type=service | grep -q "$SERVICE"; then
            echo "[$TIMESTAMP] CRITICAL - Service $SERVICE is not running" | tee -a "$ALERT_FILE" >> "$LOG_FILE"
        fi
    fi
done

# 9. Check for NetBird container health
NETBIRD_CONTAINERS=("ubuntu-management-1" "ubuntu-signal-1" "ubuntu-relay-1" "ubuntu-dashboard-1" "ubuntu-caddy-1")
for CONTAINER in "${NETBIRD_CONTAINERS[@]}"; do
    if ! docker ps --format "{{.Names}}" | grep -q "$CONTAINER"; then
        echo "[$TIMESTAMP] CRITICAL - NetBird container $CONTAINER is not running" | tee -a "$ALERT_FILE" >> "$LOG_FILE"
    fi
done

# 10. Check for Vaultwarden/Traefik health
VAULTWARDEN_CONTAINERS=("vaultwarden" "traefik-vaultwarden")
for CONTAINER in "${VAULTWARDEN_CONTAINERS[@]}"; do
    if ! docker ps --format "{{.Names}}" | grep -q "$CONTAINER"; then
        echo "[$TIMESTAMP] CRITICAL - Container $CONTAINER is not running" | tee -a "$ALERT_FILE" >> "$LOG_FILE"
    fi
done

echo "=== Security Monitor Complete ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Keep log files under control (last 1000 lines only)
tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
tail -500 "$ALERT_FILE" > "$ALERT_FILE.tmp" && mv "$ALERT_FILE.tmp" "$ALERT_FILE"
