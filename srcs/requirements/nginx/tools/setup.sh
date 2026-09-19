#!/bin/sh
set -e

if [ ! -f /etc/nginx/ssl/inception.crt ]; then
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout /etc/nginx/ssl/inception.key \
		-out /etc/nginx/ssl/inception.crt \
		-subj "/C=MA/O=42/CN=${DOMAIN_NAME}"
fi

exec nginx -g "daemon off;"
