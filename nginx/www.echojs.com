server {
	listen 80;
	listen [::]:80;
	server_name echojs.com echojs.net echojs.org www.echojs.net www.echojs.org;
	return 301 $scheme://www.echojs.com$request_uri;
}

upstream unicorn_server {
	server unix:/home/echojs/echojs/tmp/sockets/unicorn.sock
	fail_timeout=0;
}

server {
	listen 80;
	listen [::]:80;
	listen 443 ssl;
	server_name www.echojs.com;

	ssl_certificate /etc/nginx/ssl/fullchain.cer;
	ssl_certificate_key /etc/nginx/ssl/echojs.com.key;

	# openssl dhparam 4096 -out /etc/ssl/dhparam.pem
	ssl_dhparam /etc/ssl/dhparam.pem;

	ssl_protocols TLSv1.2 TLSv1.1 TLSv1;
	ssl_prefer_server_ciphers on;
	ssl_ciphers EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA512:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:ECDH+AESGCM:ECDH+AES256:DH+AESGCM:DH+AES256:!aNULL:!eNULL:!LOW:!RC4:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS;

	ssl_session_cache shared:TLS:2m;

	access_log /srv/www/www.echojs.com/logs/access.log;
	error_log /srv/www/www.echojs.com/logs/error.log;

	location / {
		root /srv/www/www.echojs.com/htdocs;

		try_files $uri @app;
	}

	location @app {
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header Host $http_host;
		proxy_redirect off;
		proxy_pass http://unicorn_server;
	}
}
