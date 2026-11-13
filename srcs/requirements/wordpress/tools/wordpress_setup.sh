#!/bin/sh
# Will crash loudly if necessary file is missing
set -e

WP_PATH="/var/www/html"

# Get passwords from secrets in docker compose file
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

echo "Setting up WordPress..."
# Download and configure WordPress if not present
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    cp -rn /usr/src/wordpress-src/* "$WP_PATH" || true

    # Set secure permissions
    # nginx is not in the www-data group, need files to be group/world-readable
    find "$WP_PATH" -type d -exec chmod 755 {} \;
    find "$WP_PATH" -type f -exec chmod 644 {} \;
    chown -R www-data:www-data "$WP_PATH"

    echo "Waiting for MariaDB..."
    until mysql -h mariadb -u "${DB_USER}" -p"${DB_PASSWORD}" \
            -e "SELECT 1" >/dev/null 2>&1; do
        sleep 2
    done

    wp config create --path="$WP_PATH" \
        --dbname="${DB_NAME}" --dbuser="${DB_USER}" \
        --dbpass="${DB_PASSWORD}" --dbhost="${DB_HOST}"
    wp config set --path="$WP_PATH" table_prefix "${WP_TABLE_PREFIX:-wp_}"
    wp config set --path="$WP_PATH" WP_DEBUG false --raw

    # The DB password should not be world-readable
    chown www-data:www-data "$WP_PATH/wp-config.php"
    chmod 640 "$WP_PATH/wp-config.php"

    wp core install --url="https://${DOMAIN_NAME}" --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" --skip-email
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" --role=editor \
        --user_pass="${WP_USER_PASSWORD}"
    echo "WordPress setup complete."
else
    echo "WordPress already initialized, skipping setup."
fi

echo "Starting PHP-FPM..."
exec php-fpm83 -F
