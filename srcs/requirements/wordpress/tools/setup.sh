#!/bin/sh
set -e

DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

until mariadb -h mariadb -u"${MYSQL_USER}" -p"${DB_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; do
	sleep 2
done

if [ ! -f wp-load.php ]; then
	wp core download --allow-root
fi

if [ ! -f wp-config.php ]; then
	wp config create --allow-root \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost=mariadb

	wp core install --allow-root \
		--url="https://${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email

	wp user create --allow-root \
		"${WP_USER}" "${WP_USER_EMAIL}" \
		--role=author \
		--user_pass="${WP_USER_PASSWORD}"

	chown -R www-data:www-data /var/www/html
fi

exec php-fpm8.2 -F
