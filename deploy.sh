#!/usr/bin/env bash
#
# VELA Waitlist — automated deployment script
# Usage: ./deploy.sh yourdomain.com
#
# What this does:
#   1. Installs nginx, PHP-FPM, certbot
#   2. Copies site files to /var/www/vela
#   3. Configures nginx with your domain
#   4. Opens firewall ports 80/443
#   5. Gets Let's Encrypt SSL certificate (HTTPS)
#   6. Sets up auto-renewal
#
# Requirements:
#   - Ubuntu 22.04+ or Debian 12+
#   - Root access
#   - Domain must already point to this server's IP (A record)
#

set -euo pipefail

# === Config ===
DOMAIN="${1:-}"
SITE_DIR="/var/www/vela"
NGINX_CONF="/etc/nginx/sites-available/vela"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# === Helpers ===
info()  { echo -e "\n\033[1;32m[+]\033[0m $1"; }
error() { echo -e "\n\033[1;31m[!]\033[0m $1" >&2; exit 1; }

# === Checks ===
[[ $EUID -eq 0 ]] || error "Run as root: sudo ./deploy.sh yourdomain.com"
[[ -n "$DOMAIN" ]] || error "Usage: ./deploy.sh yourdomain.com"

info "Deploying VELA waitlist to ${DOMAIN}..."

# === 1. Install packages ===
info "Installing nginx, PHP, certbot..."
apt-get update -qq
apt-get install -y -qq nginx php-fpm php-json php-mbstring certbot python3-certbot-nginx > /dev/null 2>&1

# Detect PHP-FPM version and socket
PHP_SOCK=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)
[[ -n "$PHP_SOCK" ]] || error "PHP-FPM socket not found. Check php-fpm service."
info "PHP-FPM socket: ${PHP_SOCK}"

# === 2. Copy site files ===
info "Deploying files to ${SITE_DIR}..."
mkdir -p "${SITE_DIR}/data"
cp "${SCRIPT_DIR}/index.html" "${SITE_DIR}/"
cp "${SCRIPT_DIR}/style.css"  "${SITE_DIR}/"
cp "${SCRIPT_DIR}/submit.php" "${SITE_DIR}/"
cp "${SCRIPT_DIR}/data/.htaccess" "${SITE_DIR}/data/"
echo '[]' > "${SITE_DIR}/data/waitlist.json"
chown -R www-data:www-data "${SITE_DIR}"
chmod 775 "${SITE_DIR}/data"
chmod 664 "${SITE_DIR}/data/waitlist.json"

# === 3. Configure nginx ===
info "Configuring nginx for ${DOMAIN}..."
cat > "${NGINX_CONF}" <<NGINX
server {
    listen 80;
    server_name ${DOMAIN};

    root ${SITE_DIR};
    index index.html index.php;

    # Never cache HTML
    location ~* \\.html\$ {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires 0;
    }

    # CSS/JS — revalidate every time
    location ~* \\.(css|js)\$ {
        add_header Cache-Control "no-cache";
        etag on;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \\.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCK};
    }

    location /data/ {
        deny all;
        return 403;
    }
}
NGINX

ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/vela
rm -f /etc/nginx/sites-enabled/default
nginx -t || error "Nginx config test failed"
systemctl restart nginx
systemctl enable nginx

# === 4. Firewall ===
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    info "Opening firewall ports 80 and 443..."
    ufw allow 80/tcp  comment 'HTTP'  >/dev/null 2>&1 || true
    ufw allow 443/tcp comment 'HTTPS' >/dev/null 2>&1 || true
fi

# === 5. SSL via Let's Encrypt ===
info "Requesting SSL certificate for ${DOMAIN}..."
certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos --register-unsafely-without-email --redirect \
    || echo "  [!] Certbot failed — make sure ${DOMAIN} DNS points to this server. You can retry: certbot --nginx -d ${DOMAIN}"

# === 6. Verify ===
info "Verifying deployment..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${DOMAIN}/" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "301" ]]; then
    info "SUCCESS! Site is live."
else
    info "Site deployed but returned HTTP ${HTTP_CODE}. Check DNS and try: curl -I http://${DOMAIN}/"
fi

echo ""
echo "============================================="
echo "  VELA Waitlist deployed!"
echo ""
echo "  URL:   https://${DOMAIN}"
echo "  Files: ${SITE_DIR}/"
echo "  Data:  ${SITE_DIR}/data/waitlist.json"
echo ""
echo "  To view submissions:"
echo "    cat ${SITE_DIR}/data/waitlist.json | python3 -m json.tool"
echo ""
echo "  SSL auto-renews via certbot timer."
echo "============================================="
