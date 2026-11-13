# What base image to start with
FROM alpine:3.23

# Install MariaDB
RUN apk add --no-cache mariadb mariadb-client mariadb-server-utils

# Define environment variables
ENV MYSQL_DATA_DIR=/var/lib/mysql \
    MYSQL_LOG_DIR=/var/log/mysql \
    MYSQL_RUN_DIR=/var/run/mysqld

# Create directories
# Permissions 700 on the log/run dirs would break the mysql user's own access
RUN mkdir -p ${MYSQL_DATA_DIR} ${MYSQL_LOG_DIR} ${MYSQL_RUN_DIR} \
    && chown -R mysql:mysql ${MYSQL_DATA_DIR} ${MYSQL_LOG_DIR} ${MYSQL_RUN_DIR} \
    && chmod 700 ${MYSQL_DATA_DIR} \
    && chmod 755 ${MYSQL_LOG_DIR} ${MYSQL_RUN_DIR}

# Copy configuration
COPY conf/mariadb.cnf /etc/my.cnf
COPY tools/mariadb_init.sh /usr/local/bin/

# Set permissions
RUN chmod +x /usr/local/bin/mariadb_init.sh

# Environment variables (can be overridden at runtime)
ENV MYSQL_DATABASE=app_db \
    MYSQL_USER=app_user

EXPOSE 3306

ENTRYPOINT ["mariadb_init.sh"]
