#!/bin/bash

# NOTE: All placeholders will be filled during ISO creation.
#(replace_panel_email, replace_panel_username, replace_panel_password, replace_db_password)
# Do NOT distribute the ISO with real passwords inside this script.
# APP_URL uses LAN IP because the panel is intended for LAN-only access.
# SSL is disabled intentionally. This appliance is designed for LAN-only use.


exec > >(tee -a /var/log/provision.log) 2>&1
set -e

debuginfo(){
  echo "==================================================="
  echo "==================================================="
  if [[ $2 -eq 0 ]]; then
    echo "$1 setup successful."
  else
    echo "$1 failed with exit code $2."
  fi
  echo "==================================================="
  echo "==================================================="
}

echo "==================================================="
echo "==================================================="
echo "The provisioning of pterodactyl is starting."
echo "==================================================="
echo "==================================================="

apt-get update
apt-get install -y software-properties-common tar curl unzip apt-transport-https ca-certificates gnupg
sleep 2

echo "==================================================="
echo "==================================================="
echo "Downloading docker"
echo "==================================================="
echo "==================================================="

# PHP PPA
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php

# Redis repo
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list

# Docker
curl -sSL https://get.docker.com/ | CHANNEL=stable bash

debuginfo "docker"

apt-get update

# PHP + MariaDB + Redis + NGINX
echo "==================================================="
echo "==================================================="
echo "Downloading php, redis and nginx."
echo "==================================================="
echo "==================================================="

apt-get install -y php8.3 php8.3-common php8.3-cli php8.3-gd php8.3-mysql php8.3-mbstring php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip mariadb-server nginx redis-server

debuginfo "php, redis and nginx" $?

sleep 2

systemctl enable --now docker
systemctl restart php8.3-fpm

# # GRUB swap accounting
echo "==================================================="
echo "==================================================="
echo "setting up grub swap accounting"
echo "==================================================="
echo "==================================================="

sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' /etc/default/grub
update-grub

debuginfo "GRUB swap accounting" $?

# Composer
echo "==================================================="
echo "==================================================="
echo "Starting composer setup."
echo "==================================================="
echo "==================================================="

export COMPOSER_HOME="$HOME/.config/composer"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

debuginfo "Composer" $?

# Pterodactyl panel
echo "==================================================="
echo "==================================================="
echo "Setting up Ptero Panel."
echo "==================================================="
echo "==================================================="

mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl && curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz && tar -xzvf panel.tar.gz

debuginfo "Pterodactyl panel" $?

echo "Changing /var/www/pterodactyl/storage and /var/www/pterodactyl/bootstrap/cache permissions."
chmod -R 755 /var/www/pterodactyl/storage /var/www/pterodactyl/bootstrap/cache

debuginfo "Permissions for pterodactyl" $?

# MariaDB setup
echo "==================================================="
echo "==================================================="
echo "Setting up mariadb."
echo "==================================================="
echo "==================================================="

systemctl restart mariadb
until mysqladmin ping >/dev/null 2>&1; do sleep 1; done

mysql -e "
CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY 'replace_db_password';
CREATE DATABASE panel;
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;"

debuginfo "MariaDB" $?

# Laravel setup
echo "==================================================="
echo "==================================================="
echo "Setting up Laravel."
echo "==================================================="
echo "==================================================="

IP=$(hostname -I | awk '{print $1}')
cd /var/www/pterodactyl && cp .env.example .env

# Dynamic APP_URL using the detected IP
sed -i "s|APP_URL=.*|APP_URL=http://$IP|" .env
sed -i "s|APP_TIMEZONE=.*|APP_TIMEZONE=UTC|" .env

# Database settings
sed -i "s|DB_HOST=.*|DB_HOST=127.0.0.1|" .env
sed -i "s|DB_PORT=.*|DB_PORT=3306|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=panel|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=pterodactyl|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=replace_db_password|" .env

# Redis + queue settings
sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|" .env
sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|" .env
sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" .env

COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
php artisan key:generate --force

# php artisan p:environment:setup \
#   --author="Admin" \
#   --url="https://example.com" \
#   --email="admin@example.com" \
#   --timezone="UTC" \
#   --cache="redis" \
#   --session="redis" \
#   --queue="redis"

# php artisan p:environment:database \
#   --host="127.0.0.1" \
#   --port="3306" \
#   --database="panel" \
#   --username="pterodactyl" \
#   --password="yourPassword"

php artisan migrate --seed --force

php artisan p:user:make \
  --email="replace_panel_email" \
  --username="replace_panel_username" \
  --name-first="Admin" \
  --name-last="A" \
  --password="replace_panel_password" \
  --admin=1 \
  --no-password

debuginfo "Laravel" $?
chown -R www-data:www-data /var/www/pterodactyl

# Cron
echo "==================================================="
echo "==================================================="
echo "Making the cron job for pterodactyl."
echo "==================================================="
echo "==================================================="

echo "* * * * * www-data php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" | tee -a /etc/crontab > /dev/null

debuginfo "Cron job" $?

# pteroq service
echo "==================================================="
echo "==================================================="
echo "Creating pteroq systemd service"
echo "==================================================="
echo "==================================================="

cat > /etc/systemd/system/pteroq.service << "EOA"
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOA

debuginfo "Pteroq" $?

systemctl enable --now redis-server
systemctl enable --now pteroq.service

# Setting up the webpage access aka NGINX
echo "==================================================="
echo "==================================================="
echo "Setting up NGINX"
echo "==================================================="
echo "==================================================="

rm /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/pterodactyl.conf << "EOF"
server {
    # Replace the example <domain> with your domain name or IP address
    listen 80;
    server_name _;

    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
debuginfo "NGINX config" $?
systemctl restart nginx

# Wings
echo "==================================================="
echo "==================================================="
echo "Creating wings"
echo "==================================================="
echo "==================================================="

mkdir -p /etc/pterodactyl

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    WINGS_ARCH="amd64"
else
    WINGS_ARCH="arm64"
fi

curl -L -o /usr/local/bin/wings \
  "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"

debuginfo "Wings" $?

chmod +x /usr/local/bin/wings
debuginfo "Wings permissions" $?

cat > /etc/systemd/system/wings.service << "EOB"
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOB

debuginfo "Wing systemd service" $?

# Firewall configuration
echo "==================================================="
echo "==================================================="
echo "Setting up firewall rules"
echo "==================================================="
echo "==================================================="

ufw allow 22/tcp      # allow ssh
ufw default deny incoming
ufw default allow outgoing

# Panel ports
ufw allow 80/tcp
ufw allow 443/tcp

# Wings ports
ufw allow 8080/tcp
ufw allow 2022/tcp

# Valheim server ports (UDP only)
ufw allow 2456/udp
ufw allow 2457/udp
ufw allow 2458/udp

# Enable firewall non-interactively
ufw --force enable


systemctl enable --now wings
systemctl disable postinstall.service

finish_message() {
  local msg="
===================================================
===================================================
The provisioning script of pterodactyl has run it's course to the end.
===================================================
===================================================
"
  echo "$msg"
  echo "$msg" > /dev/tty1
}

finish_message
