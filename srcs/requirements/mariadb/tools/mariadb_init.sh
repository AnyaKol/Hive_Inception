#!/bin/sh
# Will crash loudly if necessary file is missing
set -e

# Get passwords from secrets in docker compose file
DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

echo "Starting MariaDB initialization..."

# Initialize MySQL data directory if it doesn't exist
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing data directory..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

    # Start the server (no networking for setup)
    echo "Starting temporary MariaDB server for setup..."
    mariadbd --skip-networking --socket=/run/mysqld/mysqld.sock --user=mysql &
    pid="$!"

    # Wait for MariaDB to be ready
    echo "Waiting for MariaDB to be ready..."
    until mariadb-admin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; do
        sleep 1
    done
    echo "MariaDB is ready!"

    # Run setup SQL: create database and users
    echo "Running setup SQL..."
    mariadb --socket=/run/mysqld/mysqld.sock -u root << EOF
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
    CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOF

    # Shut down temporary server
    echo "Shutting down temporary MariaDB..."
    mariadb-admin --socket=/run/mysqld/mysqld.sock -u root -p"${DB_ROOT_PASSWORD}" shutdown

    # Wait for shutdown
    wait "$pid" || true
fi

# Start MariaDB normally (with networking)
echo "Initialization complete. Starting MariaDB..."
exec mariadbd --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock
