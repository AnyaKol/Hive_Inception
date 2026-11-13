# What base image to start with
FROM alpine:3.23

# Set environment variables for WP-CLI
ENV WP_CLI_VERSION=2.12.0
ENV WP_CLI_SHA256="ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c"

# Download and extract WordPress at build time (pinned version)
ENV WP_VERSION=6.8.2

RUN wget -q https://wordpress.org/wordpress-${WP_VERSION}.tar.gz -O /tmp/wp.tar.gz \
    && tar -xzf /tmp/wp.tar.gz -C /usr/src/ \
    && rm /tmp/wp.tar.gz \
    && mv /usr/src/wordpress /usr/src/wordpress-src

# Install PHP-FPM and required extensions
RUN apk add --no-cache \
  php83 \
  php83-fpm \
  php83-mysqli \
  php83-json \
  php83-curl \
  php83-dom \
  php83-mbstring \
  php83-openssl \
  php83-xml \
  php83-phar \
  php83-session \
  mariadb-client \
  curl \
  # Create www-data user and group if they do not exist
  && if ! getent group www-data > /dev/null; then addgroup -S www-data; fi \
  && if ! getent passwd www-data > /dev/null; then adduser -S -G www-data www-data; fi \
  && mkdir -p /var/www/html \
  && chown -R www-data:www-data /var/www/html \
  && chmod -R 755 /var/www/html

# Check if php is in the php83 package; wp-cli needs #!/usr/bin/env php
RUN ln -s /usr/bin/php83 /usr/bin/php

# Install WP-CLI with checksum verification
RUN curl -fsSL -o /tmp/wp-cli.phar \
    "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
  && echo "${WP_CLI_SHA256}  /tmp/wp-cli.phar" | sha256sum -c - \
  && chmod +x /tmp/wp-cli.phar && mv /tmp/wp-cli.phar /usr/local/bin/wp

# Create WordPress directory
WORKDIR /var/www/html

# Copy PHP-FPM configuration (correct version)
COPY conf/wordpress.conf /etc/php83/php-fpm.d/www.conf

# Copy and set permissions for setup script
COPY tools/wordpress_setup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wordpress_setup.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wordpress_setup.sh"]
