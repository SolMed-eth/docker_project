FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	nginx \
	openssl \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -f /etc/nginx/sites-enabled/default \
	&& rm -rf /var/www/html/* \
	&& sed -i "s/ssl_protocols .*/ssl_protocols TLSv1.2 TLSv1.3;/" /etc/nginx/nginx.conf

COPY conf/nginx.conf /etc/nginx/conf.d/default.conf
COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh \
	&& mkdir -p /etc/nginx/ssl

EXPOSE 443

ENTRYPOINT ["setup.sh"]
