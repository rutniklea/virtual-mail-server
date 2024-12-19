#!/bin/bash

# Enhanced Virtual Mail Server Setup Script
# Author: Lea Rutnik
# GitHub: https://github.com/rutniklea

# Variables
DOMAIN="learutnik.com"
MAIL_HOST="mail.$DOMAIN"
ADMIN_EMAIL="admin@$DOMAIN"
POSTFIX_MAIN_CF="/etc/postfix/main.cf"
DOVECOT_CONF="/etc/dovecot/dovecot.conf"
CERT_PATH="/etc/letsencrypt/live/$MAIL_HOST/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/$MAIL_HOST/privkey.pem"

echo "=== Starting Virtual Mail Server setup for domain: $DOMAIN ==="

# Step 1: Update and install required packages
echo ">>> Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo ">>> Installing Postfix, Dovecot, and Roundcube..."
sudo apt install -y postfix dovecot-core dovecot-imapd dovecot-lmtpd certbot mailutils roundcube

# Step 2: Configure SSL/TLS with Certbot
echo ">>> Configuring SSL/TLS with Certbot..."
sudo certbot certonly --standalone -d $MAIL_HOST

# Step 3: Configure Postfix
echo ">>> Configuring Postfix..."
sudo cp $POSTFIX_MAIN_CF $POSTFIX_MAIN_CF.bak
sudo tee $POSTFIX_MAIN_CF > /dev/null <<EOL
myhostname = $MAIL_HOST
mydomain = $DOMAIN
myorigin = /etc/mailname
inet_interfaces = all
home_mailbox = Maildir/
smtpd_tls_cert_file=$CERT_PATH
smtpd_tls_key_file=$KEY_PATH
smtpd_use_tls=yes
smtpd_tls_security_level=encrypt
smtpd_tls_auth_only=yes
smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination
EOL
sudo systemctl restart postfix

# Step 4: Configure Dovecot
echo ">>> Configuring Dovecot..."
sudo cp $DOVECOT_CONF $DOVECOT_CONF.bak
sudo tee $DOVECOT_CONF > /dev/null <<EOL
protocols = imap lmtp
mail_location = maildir:~/Maildir
ssl = yes
ssl_cert = <$CERT_PATH
ssl_key = <$KEY_PATH
passdb {
    driver = pam
}
userdb {
    driver = passwd
}
protocol lda {
    postmaster_address = $ADMIN_EMAIL
}
EOL
sudo systemctl restart dovecot

# Step 5: Configure Roundcube
echo ">>> Setting up Roundcube..."
sudo ln -s /usr/share/roundcube /var/www/html/roundcube
sudo systemctl reload apache2

# Step 6: Add the `info` email user
echo ">>> Creating the email user 'info'..."
sudo adduser --disabled-password --gecos "" info
echo ">>> Setting password for 'info'..."
echo "info:$(openssl rand -base64 12)" | sudo chpasswd
echo ">>> User 'info@$DOMAIN' has been created."

# Step 7: Test the configuration
echo ">>> Testing configurations..."
sudo postfix check
sudo dovecot reload
echo ">>> Configuration tests complete."

# Step 8: Set Up Log Monitoring (Optional)
echo ">>> Setting up log monitoring..."
sudo apt install -y pflogsumm
sudo pflogsumm /var/log/mail.log | less

# Final Summary
echo "=== Setup Complete ==="
echo "Access Roundcube at https://$MAIL_HOST/roundcube"
echo "Ensure the following DNS records are set up for $DOMAIN:"
echo "  MX: $MAIL_HOST"
echo "  A: $MAIL_HOST"
echo "  SPF: v=spf1 mx ~all"
echo "  DKIM: Generate and configure"
echo "  DMARC: Generate and configure"
echo "User info@$DOMAIN has been created. Password is auto-generated."
