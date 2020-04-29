#!/bin/sh

# User Password
user_name="ADD_YOUR_USERNAME_HERE"
user_password="ADD_YOUR_PASSWORD_HERE"

# update freebsd
echo "q" | freebsd-update fetch
freebsd-update install

# update packages and stuff
pkg update
pkg upgrade --yes

# Install a bunch of standard stuff
pkg install --yes bash sudo wget nano py27-certbot unzip

# Add certbot weekly check
echo 'weekly_certbot_enable="YES"' >> /etc/periodic.conf

# Add Certbot checks to cron
crontab -l > mycron
echo "0 0 * * * /usr/local/bin/certbot-2.7 renew --quiet" >> mycron
crontab mycron
rm mycron

# Install apache
pkg install --yes apache24
sysrc apache24_enable=yes

# Install mariadb
pkg install --yes mariadb102-server mariadb102-client
sysrc mysql_enable="YES"

# Configure MariaDB
wget -O /usr/local/etc/my.cnf https://raw.githubusercontent.com/biondizzle/freebsd-lamp/master/my.conf

# Start mariadb
service mysql-server start

## Need to emulate running /usr/local/bin/mysql_secure_installation ##
## These below commands could also do the trick ##
#/usr/local/bin/mysqladmin -u root password 'new-password'
#/usr/local/bin/mysqladmin -u root -h apture_dev password 'new-password'

# Generate random root password
mariadb_root_pass=$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 16; echo)

# Make sure that NOBODY can access the server without a password
mysql -e "UPDATE mysql.user SET Password = PASSWORD('$mariadb_root_pass') WHERE User = 'root'"
# Kill the anonymous users
mysql -e "DROP USER ''@'localhost'"
# Because our hostname varies we'll use some Bash magic here.
mysql -e "DROP USER ''@'$(hostname)'"
# Kill off the demo database
mysql -e "DROP DATABASE test"
# Make our changes take effect
mysql -e "FLUSH PRIVILEGES"

# Save root password in plain text like a cuck
touch /root/mariadb_root.txt
echo $mariadb_root_pass >> /root/mariadb_root.txt

# Install php
pkg install --yes mod_php73 php73 php73-mysqli php73-session php73-dom php73-xml php73-bz2 php73-intl php73-xmlwriter php73-hash php73-ftp php73-curl php73-ctype php73-tokenizer php73-json php73-zlib php73-zip php73-xmlreader php73-filter php73-gd php73-openssl php73-gettext php73-mbstring php73-phar php73-pgsql php73-imap php73-pdo_mysql php73-pdo_odbc php73-soap php73-iconv php73-fileinfo php73-openssl

# Add a php config
wget -O /usr/local/etc/php.ini https://raw.githubusercontent.com/biondizzle/freebsd-lamp/master/php73.ini

# Apache to serve up php
touch /usr/local/etc/apache24/Includes/php.conf

cat << EOF > /usr/local/etc/apache24/Includes/php.conf
<IfModule dir_module>
  DirectoryIndex index.php index.html
  <FilesMatch "\.php$">
      SetHandler application/x-httpd-php
  </FilesMatch>
  <FilesMatch "\.phps$">
      SetHandler application/x-httpd-php-source
  </FilesMatch>
</IfModule>
EOF

# Apache SSL Support
touch /usr/local/etc/apache24/modules.d/020_mod_ssl.conf

cat << EOF > /usr/local/etc/apache24/modules.d/020_mod_ssl.conf
Listen 443
SSLProtocol ALL -SSLv2 -SSLv3
SSLCipherSuite HIGH:MEDIUM:!aNULL:!MD5
SSLPassPhraseDialog  builtin
SSLSessionCacheTimeout  300
EOF

# Apache config
wget -O /usr/local/etc/apache24/httpd.conf https://raw.githubusercontent.com/biondizzle/freebsd-lamp/master/httpd.conf

# PHPMyAdmin Intsall
wget -O /usr/local/etc/phpMyAdmin-5.0.2-all-languages.zip https://files.phpmyadmin.net/phpMyAdmin/5.0.2/phpMyAdmin-5.0.2-all-languages.zip
unzip /usr/local/etc/phpMyAdmin-5.0.2-all-languages.zip -d /usr/local/etc
mv /usr/local/etc/phpMyAdmin-5.0.2-all-languages /usr/local/etc/phpmyadmin
cp /usr/local/etc/phpmyadmin/config.sample.inc.php /usr/local/etc/phpmyadmin/config.inc.php
mkdir -p /usr/local/etc/phpmyadmin/tmp
chmod -R 777 /usr/local/etc/phpmyadmin/tmp

# Add blowfish secret to phpmyadmin config
phpmyadmin_blowfish=$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 32; echo)
echo '$cfg["blowfish_secret"] = "'$phpmyadmin_blowfish'";' >> /usr/local/etc/phpmyadmin/config.inc.php

# PHPMyAdmin Apache Support
touch /usr/local/etc/apache24/Includes/phpmyadmin.conf

cat << EOF > /usr/local/etc/apache24/Includes/phpmyadmin.conf
Alias /phpmyadmin /usr/local/etc/phpmyadmin

<Directory /usr/local/etc/phpmyadmin>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    DirectoryIndex index.php
</Directory>

# Disallow web access to directories that don't need it
<Directory /usr/local/etc/phpmyadmin/libraries>
    Require all denied
</Directory>
<Directory /usr/local/etc/phpmyadmin/setup/lib>
    Require all denied
</Directory>
EOF

# Add $user_name user
pw useradd $user_name -g wheel
pw groupmod wheel -m $user_name
pw groupmod www -m $user_name
echo $user_password | pw mod user $user_name -h 0

# Give $user_name user ownership of the apache directory
chown -R $user_name:www /usr/local/www

# Install Samba
pkg install --yes samba410
sysrc samba_server_enable="YES"

touch /usr/local/etc/smb4.conf

cat << EOF > /usr/local/etc/smb4.conf
[APACHE ROOT]
path = /usr/local/www
valid users = $user_name
read only = no
EOF

echo -e "$user_password\n$user_password" | pdbedit -a -u $user_name -t

# Start samba
service samba_server start

# Start Apache
service apache24 start

##### FIREWALL: BEGIN ####

#### WARNING - FIREWALL SETUP MIGHT NOT WORK FOR YOU WITHOUT MODIFICATION - ####

IP=$(curl --silent http://icanhazip.com)

# Firewall
echo 'pf_enable="YES"' >> /etc/rc.conf
echo 'pf_rules="/usr/local/etc/pf.conf"' >> /etc/rc.conf
echo 'pflog_enable="YES"' >> /etc/rc.conf
echo 'pflog_logfile="/var/log/pflog"' >> /etc/rc.conf

# Config firewall
cat << EOF > /usr/local/etc/pf.conf
ext_if="vtnet0"
ext_if_ip="$IP"
martians = "{ 127.0.0.0/8 }"
webports = "{http, https}"
int_tcp_services = "{www, https, ssh}"
### SET UDP SERVICES HERE ###
#int_udp_services = "{}"
set skip on lo
set loginterface \$ext_if
scrub in all
block return in log all
block out all
block drop in quick on \$ext_if from \$martians to any
block drop out quick on \$ext_if from any to \$martians
antispoof quick for \$ext_if
pass in inet proto tcp to \$ext_if port ssh
pass inet proto icmp icmp-type echoreq
pass proto tcp from any to \$ext_if port \$webports
pass out quick on \$ext_if proto tcp to any port \$int_tcp_services
### IF UDP SERVICES ARE SET, UNCOMMENT THIS ###
#pass out quick on \$ext_if proto udp to any port \$int_udp_services
EOF

# Start Firewall - This will most likely kill your current ssh session
service pf start

##### FIREWALL: END ####

# reboot the server for good measure
reboot