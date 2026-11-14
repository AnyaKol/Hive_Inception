# ft_Inception
Rank-05

## Create a custom network
docker network create inception-network

## List networks
docker network ls

## Inspect the network
docker network inspect inception-network

## Connect a running container
docker network connect inception-network <container_id_or_name>

## Create a httpd apache server connected to the network
docker run --rm --name client --network inception-network -d httpd

## To enter shell
docker exec -it client sh

## If ping is missing
apk add iputils    # For Alpine
apt-get update && apt-get install iputils-ping   # For Debian/Ubuntu

## To get an IP address
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container_id_or_name>


# MariaDB
## To check if socket file exist on container
docker exec -it <container_id_or_name> ls -l /run/mysqld/mysqld.sock

## To check maria db
docker exec -it <container_id_or_name> mysqladmin ping -u root -p


# Wordpress
## If we want to test wp container we can use this:
docker run -d \
  -e DB_HOST=dummyhost \
  -e DB_NAME=dummydb \
  -e DB_USER=dummyuser \
  -e DB_PASSWORD=dummypassword \
  mywp

## Then
docker exec -it docker_id_name cat /var/www/html/wp-config.php

## And then check with:
cat /var/www/html/wp-config.php


# Nginx
## Check certificate
docker exec -it docker_id_name ls /etc/nginx/ssl/

# Volumes
## Create volumes
docker volume create mariadb_data
docker volume create wordpress_data

## Inspect a volume
docker volume inspect mariadb_data


# Testing
## Check container status:
docker ps

## Check container logs
docker logs mariadb
docker logs wordpress
docker logs nginx

## Access container shell
docker exec -it mariadb bash

## Test database connection:
docker exec -it mariadb mysql -u root -p

## Test the website
curl -k https://login.42.fr

## Cannot connect to database
### Test network connectivity
docker exec wordpress ping mariadb

### Check database is listening
docker exec mariadb netstat -tuln | grep 3306

### Test database connection
docker exec mariadb mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SHOW DATABASES;"

## NGINX returns 502 Bad Gateway
### Check if WordPress container is running
docker ps | grep wordpress

### Check PHP-FPM is listening
docker exec wordpress netstat -tuln | grep 9000

### Check NGINX configuration
docker exec nginx nginx -t

## Performance Issues
### Monitor resource usage
docker stats

### Check disk usage
df -h
du -sh /home/${USER}/data/*

### Monitor network
docker exec nginx ss -tuln


# Docker containers basic commands
## To build
docker build -t <container_image_name> .

## To run
docker run -d <container_image_name>

## To run with name
docker run -d --name my_app image

## To check all docker containers
docker ps -a

## To stop containers and remove images
docker rm -f $(docker ps -aq) &&  docker rmi -f $(docker images -aq)

## To run a compose file
docker compose up

## Force rebuild in background 
docker compose up --build -d

## Down composer
docker compose down

## To delete content from data volumes
sudo rm -rf /home/user/data/wordpress/
sudo rm -rf /home/user/data/mariadb/

## To create again
mkdir -p /home/user/data/wordpress/
mkdir -p /home/user/data/mariadb/

## To check db connection manually (from wp contaier)
docker exec -it wordpress bash
apt-get update && apt-get install -y mariadb-client
mysql -h mariadb -u"$DB_USER" -p

## To acces mariadb user table from root (inside mariadb contaier)
docker exec -it mariadb mysql -u root -p

## And from wp_user (inside mariadb contaier)
docker exec -it mariadb mysql -u"$DB_USER" -p

## To check env values
docker exec -it mariadb env
docker exec -it wordpress env