#!/bin/sh

DOMAIN=false
ALIAS=false
GET_CERT=false

while getopts 'cd:a:' flag; do # Note: If a character is followed by a colon (e.g. f:), that option is expected to have an argument.
  case "${flag}" in
    d) DOMAIN="${OPTARG}" ;;
    a) ALIAS="${OPTARG}" ;;
    c) GET_CERT=true ;;
  esac
done

if [ $DOMAIN == false ]
then
   echo "NO DOMAIN!!!!!"
   exit 1
fi

# Set some things based off if we have an alias or not
ALIAS_VHOST_LINE=""
ALIAS_CERBOT_LINE=""
if [ $ALIAS != false ]
then
    ALIAS_VHOST_LINE="ServerAlias $ALIAS"
    ALIAS_CERBOT_LINE="-d $ALIAS"
fi

# Create directory
mkdir -p /usr/local/www/$DOMAIN/public

# Create non ssl vhost block
touch /usr/local/etc/apache24/Includes/$DOMAIN.conf

cat << EOF > /usr/local/etc/apache24/Includes/$DOMAIN.conf
<VirtualHost *:80>

    ServerName $DOMAIN
    $ALIAS_VHOST_LINE
    DocumentRoot /usr/local/www/$DOMAIN/public

    <Directory /usr/local/www/$DOMAIN/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    #RewriteEngine on
    #RewriteCond %{SERVER_NAME} =$DOMAIN [OR]
    #RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]

</VirtualHost>
EOF

# Restart apache
service apache24 restart

if [ $GET_CERT != false ]
then
service pf stop

# Get a cert
sudo certbot-2.7 certonly --webroot -w /usr/local/www/$DOMAIN/public -d $DOMAIN $ALIAS_CERBOT_LINE

# Create ssl vhost block
touch /usr/local/etc/apache24/Includes/$DOMAIN-ssl.conf

cat << EOF > /usr/local/etc/apache24/Includes/$DOMAIN-ssl.conf
<VirtualHost *:443>

ServerName $DOMAIN
    $ALIAS_VHOST_LINE
    DocumentRoot /usr/local/www/$DOMAIN/public

    <Directory /usr/local/www/$DOMAIN/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    SSLEngine on
    SSLCertificateFile /usr/local/etc/letsencrypt/live/$DOMAIN/cert.pem
    SSLCertificateKeyFile /usr/local/etc/letsencrypt/live/$DOMAIN/privkey.pem
    SSLCertificateChainFile /usr/local/etc/letsencrypt/live/$DOMAIN/chain.pem
</VirtualHost>
EOF

# Restart apache
service apache24 restart

# Alert User
echo "DO NOT FORGET TO UNCOMMMENT THE REDIRECT IN: /usr/local/etc/apache24/Includes/$DOMAIN.conf"

service pf start
fi

echo "COMPLETE!";