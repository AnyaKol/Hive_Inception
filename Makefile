# ---------- VARIABLES ------------------------------------------------------- #
NAME = inception
COMPOSE = docker compose
COMPOSE_FILE = srcs/docker-compose.yml
COMPOSE_CMD = $(COMPOSE) -f $(COMPOSE_FILE)

# DATA_DIR = /home/$(USER)/data
# Read value of DATA_DIR from ENV
include srcs/.env

# ---------- RULES ----------------------------------------------------------- #
all: up

# Create data directories if necessary
$(DATA_DIR)/mariadb:
	mkdir -p $(DATA_DIR)/mariadb

$(DATA_DIR)/wordpress:
	mkdir -p $(DATA_DIR)/wordpress

# Build images without starting containers.
build: $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	$(COMPOSE_CMD) build

# Build images (if needed) and start containers in the background.
up: $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	$(COMPOSE_CMD) up --build -d

# Stop and remove containers + networks; volumes and images are kept.
down:
	$(COMPOSE_CMD) down

# Stop and remove containers + networks, and delete the project images.
# Volumes and the data in $(DATA_DIR) are kept.
clean:
	$(COMPOSE_CMD) down --rmi all

# Full clean, remove data volumes and delete local images (-v removes volumes
# defined in compose file)
fclean: clean
	$(COMPOSE_CMD) down -v
	sudo rm -rf $(DATA_DIR)

# Rebuild everything
re: fclean all

# ---------- EXTRAS ---------------------------------------------------------- #
.PHONY: all build up down clean fclean re
