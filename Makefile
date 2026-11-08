NAME        = inception
COMPOSE     = docker compose
COMPOSE_FILE = srcs/docker-compose.yml

COMPOSE_CMD = $(COMPOSE) -f $(COMPOSE_FILE)

all: up

# Build images (if needed) and start containers in the background.
up:
	$(COMPOSE_CMD) up --build -d

# Build images without starting containers.
build:
	$(COMPOSE_CMD) build

# Start existing containers without rebuilding.
start:
	$(COMPOSE_CMD) start

# Stop containers, keep containers and volumes.
stop:
	$(COMPOSE_CMD) stop

# Stop and remove containers + networks; volumes and images are kept.
down:
	$(COMPOSE_CMD) down

# Stop and remove everything in the compose file: containers, networks,
# images and the WordPress database/website volumes.
clean: down
	-$(COMPOSE_CMD) down -v --rmi all
	-docker volume rm $$(docker volume ls -q --filter name=inception_) 2>/dev/null || true

# Fully stop, remove data volumes and delete local images.
fclean: clean
	-docker system prune -af 2>/dev/null || true

# Follow logs of all services.
logs:
	$(COMPOSE_CMD) logs -f

# Show container status.
ps:
	$(COMPOSE_CMD) ps

.PHONY: all up build start stop down clean fclean logs ps
