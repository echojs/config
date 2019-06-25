# Install required packages

	apt-get update
	apt-get -y install build-essential nginx redis-server ruby ruby-dev
	gem install --no-rdoc --no-ri bundler unicorn

# Create the echojs user

	adduser --disabled-password echojs

# Clone the echojs repository and create required directories

	cd /home/echojs
	git clone https://github.com/echojs/echojs.git
	cd echojs
	bundle install
	mkdir -p log tmp/pids tmp/sockets
	touch tmp/pids/unicorn.pid
	chown -R echojs:echojs /home/echojs/
	cd

# Configure unicorn

	cp init.d/unicorn /etc/init.d
	update-rc.d unicorn defaults 99
	service unicorn start

# Configure nginx

	mkdir -p /srv/www/www.echojs.com/htdocs /srv/www/www.echojs.com/logs
	cp nginx/www.echojs.com /etc/nginx/sites-available
	ln -s -t /etc/nginx/sites-enabled/ /etc/nginx/sites-available/www.echojs.com
	chown -R www-data:www-data /srv/www

# Copy the echojs assets

	cp -r /home/echojs/echojs/public/ /srv/www/www.echojs.com/htdocs

# Copy existing redis database

	service redis-server stop
	cp dump.rdb /var/lib/redis
	chown -R redis:redis /var/lib/redis/dump.rdb
	service redis-server start

# SSL/TLS configuration

## Generate dhparam.pem

	openssl dhparam -out /etc/ssl/dhparam.pem 4096

## Copy existing certificates

	mkdir /etc/nginx/ssl
	cp ssl/* /etc/nginx/ssl
	service nginx reload

## Install acme.sh

	git clone https://github.com/Neilpang/acme.sh.git
	cd acme.sh
	./acme.sh --install

## Issue and install a certificate

	./acme.sh --issue -d echojs.com -d www.echojs.com -w /srv/www/www.echojs.com/htdocs/
	./acme.sh --install-cert -d echojs.com --key-file /etc/nginx/ssl/echojs.com.key --fullchain-file /etc/nginx/ssl/fullchain.cer --reloadcmd "service nginx force-reload"

## Manually renew certificate

	./acme.sh -r -d echojs.com
	service nginx reload

# Hourly Redis database backup

	crontab -e

Then add the following line:

	0 * * * * tar cfz /home/echojs/echojs-$(date +\%Y\%m\%d-\%H\%M).tar.gz /var/lib/redis/dump.rdb

# Email service

In order to allow users to recover their passwords, edit `app_config.rb` to
set `MailRelay`.
