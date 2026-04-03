# VELA Waitlist — Deployment Instructions

This is a waitlist landing page for VELA, a women's health AI platform (35+).

## Quick Deploy

1. Point a domain (A record) to the server's IP address
2. SSH into the server as root
3. Clone this repo and run:

```bash
git clone https://github.com/misha-lyalin/vela-waitlist.git
cd vela-waitlist
sudo ./deploy.sh yourdomain.com
```

The script installs nginx + PHP + certbot, deploys the site, configures HTTPS, and opens firewall ports. Takes about 2 minutes.

## Requirements

- Ubuntu 22.04+ or Debian 12+
- Root access (sudo)
- Domain with DNS A record pointing to this server

## Structure

- `index.html` — landing page (hero, features, example protocol, waitlist form)
- `style.css` — styles (mobile-responsive)
- `submit.php` — form handler (validation, deduplication, rate limiting, saves to JSON)
- `data/waitlist.json` — submissions storage (protected by .htaccess + nginx)
- `deploy.sh` — one-command deployment script

## Viewing Submissions

```bash
cat /var/www/vela/data/waitlist.json | python3 -m json.tool
```

## After Deployment

To update the site, edit files locally and copy to server:
```bash
scp index.html style.css submit.php root@SERVER:/var/www/vela/
```
