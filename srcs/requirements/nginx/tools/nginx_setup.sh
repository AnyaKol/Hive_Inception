#!/bin/sh
# Will crash loudly if necessary file is missing
set -e

# Ensure SSL directory exists
mkdir -p /etc/nginx/ssl

# Default domain if not provided
export DOMAIN_NAME="${DOMAIN_NAME:-localhost}"
envsubst '${DOMAIN_NAME}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

# Generate SSL certificate if it doesn't exist
if [ ! -f /etc/nginx/ssl/nginx.crt ]; then
    echo "Generating self-signed SSL certificate for ${DOMAIN_NAME}..."

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/nginx.key \
        -out /etc/nginx/ssl/nginx.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${DOMAIN_NAME}"

    chmod 600 /etc/nginx/ssl/nginx.key
    chmod 644 /etc/nginx/ssl/nginx.crt

    echo "SSL certificate generated at /etc/nginx/ssl/"
else
    echo "SSL certificate already exists. Skipping generation."
fi

# Test nginx configuration before starting
echo "Testing nginx configuration..."
nginx -t
echo "Nginx configuration test passed."

# Start nginx in foreground (PID 1)
echo "Starting Nginx..."
exec nginx -g "daemon off;"
