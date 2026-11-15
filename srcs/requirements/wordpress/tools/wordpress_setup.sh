#!/bin/sh
# Will crash loudly if necessary file is missing
set -e

WP_PATH="/var/www/html"

# Get passwords from secrets in docker compose file
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

echo "Setting up WordPress..."
if [ "${HTTPS_PORT:-443}" = "443" ]; then
    WP_URL="https://${DOMAIN_NAME}"
else
    WP_URL="https://${DOMAIN_NAME}:${HTTPS_PORT}"
fi

# Wait the database on every start
echo "Waiting for MariaDB..."
    until mysql -h mariadb -u "${DB_USER}" -p"${DB_PASSWORD}" \
            -e "SELECT 1" >/dev/null 2>&1; do
        sleep 2
    done

# Step 1: files + wp-config.php (skipped if the config already exists)
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "Copying WordPress files and creating wp-config.php..."
    cp -rn /usr/src/wordpress-src/* "$WP_PATH" || true

    # Set secure permissions
    # nginx is not in the www-data group, need files to be group/world-readable
    find "$WP_PATH" -type d -exec chmod 755 {} \;
    find "$WP_PATH" -type f -exec chmod 644 {} \;
    chown -R www-data:www-data "$WP_PATH"

    wp config create --path="$WP_PATH" \
        --dbname="${DB_NAME}" --dbuser="${DB_USER}" \
        --dbpass="${DB_PASSWORD}" --dbhost="${DB_HOST}"
    wp config set --path="$WP_PATH" table_prefix "${WP_TABLE_PREFIX:-wp_}"
    wp config set --path="$WP_PATH" WP_DEBUG false --raw

    # The DB password should not be world-readable
    chown www-data:www-data "$WP_PATH/wp-config.php"
    chmod 640 "$WP_PATH/wp-config.php"
fi

# Step 2: create WordPress tables + admin (skipped if already installed)
if ! wp core is-installed --path="$WP_PATH" 2>/dev/null; then
    echo "Installing WordPress..."
    wp core install --url="${WP_URL}" --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" --skip-email
fi

# Step 3: second user (skipped if it already exists)
if ! wp user get "${WP_USER}" --path="$WP_PATH" >/dev/null 2>&1; then
    echo "Creating user ${WP_USER}..."
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" --role=editor \
        --user_pass="${WP_USER_PASSWORD}"
fi

# Updating homepage in case of port change
wp option update home    "$WP_URL" --path="$WP_PATH"
wp option update siteurl "$WP_URL" --path="$WP_PATH"

echo "WordPress setup complete."

echo "Starting PHP-FPM..."
exec php-fpm83 -F
