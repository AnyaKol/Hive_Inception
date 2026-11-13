# What base image to start with
FROM alpine:3.23

# Install nginx and openssl (gettext needed for envsubst)
RUN apk add --no-cache nginx openssl gettext

# Create nginx user/group
RUN addgroup -S nginx || true \
    && adduser -S -G nginx -g nginx nginx || true

# Copy configuration files from host to container
COPY conf/nginx.conf /etc/nginx/templates/nginx.conf.template
COPY tools/nginx_setup.sh /usr/local/bin/

# Set permissions
RUN chmod +x /usr/local/bin/*.sh

# Document which port the container uses (just document!)
EXPOSE 443

ENTRYPOINT ["/usr/local/bin/nginx_setup.sh"]
