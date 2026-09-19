FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	mariadb-server \
	&& rm -rf /var/lib/apt/lists/*

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh \
	&& mkdir -p /run/mysqld \
	&& chown -R mysql:mysql /run/mysqld

EXPOSE 3306

ENTRYPOINT ["setup.sh"]
