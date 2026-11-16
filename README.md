*This project has been created as part of the 42 curriculum by akolupae.*

# Inception

## Description

Inception is a system administration project. The goal is to build a small web
infrastructure with Docker Compose, where every service runs in its own
container built from a Dockerfile. No ready-made images are used except the
Alpine base image.

The stack serves a WordPress website over HTTPS:

```
            host :${HTTPS_PORT} (TLSv1.2 / TLSv1.3)
                          │
                ┌─────────▼─────────┐
                │       nginx       │  only entry point
                └─────────┬─────────┘
                          │ FastCGI :9000
                ┌─────────▼─────────┐
                │ wordpress+php-fpm │
                └─────────┬─────────┘
                          │ MySQL :3306
                ┌─────────▼─────────┐
                │      mariadb      │
                └───────────────────┘
        all three on the "inception" bridge network

  wp_data  → /home/<login>/data/wordpress   (nginx + wordpress)
  db_data  → /home/<login>/data/mariadb     (mariadb)
```

### Use of Docker and sources in the project

```
.
├── Makefile                  builds and runs the stack via docker compose
├── secrets/                  one password per file, mounted as Docker secrets
│   ├── db_root_password.txt
│   ├── db_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                  non-secret settings (domain, data dir, users, port)
    ├── docker-compose.yml    services, network, volumes, secrets
    └── requirements/
        ├── mariadb/
        │   ├──Dockerfile
        │   ├──conf
        │   │   └──mariadb.cnf
        │   └──tools
        │       └──mariadb_init.sh
        ├── nginx/
        │   ├──Dockerfile
        │   ├──conf
        │   │   └──nginx.conf
        │   └──tools
        │       └──nginx_setup.sh
        └── wordpress/
            ├──Dockerfile
            ├──conf
            │   └──wordpress.conf
            └──tools
                └──wordpress_setup.sh
```

Each service has a `Dockerfile`, a `conf/` folder with its configuration and a
`tools/` folder with its entrypoint script:

- **nginx**: on first start it generates a self-signed certificate for
  `DOMAIN_NAME`, fills the domain and port into `nginx.conf` with `envsubst`,
  checks the config with `nginx -t` and then runs nginx in the foreground. It
  accepts only TLSv1.2 and TLSv1.3, serves static files from the shared
  WordPress volume and passes `.php` requests to `wordpress:9000`.
- **wordpress**: WordPress 6.8.2 and WP-CLI 2.12.0 (checksum verified) are
  downloaded at build time. On start the script waits for MariaDB. If the
  volume is empty, it copies the WordPress files and writes `wp-config.php`,
  installs the site with an administrator, and creates a second user with the
  editor role. Then it runs `php-fpm83 -F` in the foreground.
- **mariadb**: on first start it initialises the data directory and sets the
  root password. It also creates the WordPress database and user, using a
  temporary server with networking turned off. Then it starts `mariadbd`
  normally.

### Main design choices

- **Base image:** `alpine:3.23` for all three images. It is small, quick to
  build and the tag is pinned (no `latest`).
- **PID 1:** every entrypoint script ends with `exec`, so the real daemon
  (nginx, php-fpm, mariadbd) becomes PID 1, runs in the foreground and gets
  stop signals directly. There is no `tail -f`, `sleep infinity` or
  `while true` keeping a container alive.
- **Idempotent setup:** each init step checks whether it has already been
  done, such as an existing data directory, `wp-config.php` or user. Restarting
  or rebuilding a container never overwrites existing data.
- **Restart policy:** `restart: always` on every service, so a crashed
  container comes back on its own.
- **No hardcoded login:** `DOMAIN_NAME` and `DATA_DIR` are built from
  `${USER}` in `srcs/.env`. The Makefile includes the same file, so the
  project runs without changes on any machine.
- **Users:** the WordPress administrator is called `chief`, because the
  subject forbids names containing "admin". The second user is `editor` and
  has role `editor` - ability to edit other peoples posts.

### Virtual Machines vs Docker

A virtual machine emulates a whole computer and runs its own kernel on top of
a hypervisor. That gives strong isolation, but each VM needs gigabytes of disk,
reserved RAM and a full OS boot. A Docker container is an isolated process
that shares the host kernel, kept apart with namespaces and cgroups. It starts
in about a second, its image is only megabytes and many containers can run on
one host. The cost is weaker isolation, since all containers share one kernel.
In this project the whole stack runs inside one VM and Docker splits the
services inside it.

### Secrets vs Environment Variables

Environment variables are easy to use, but they can be read by anything that
can inspect the container. They show up in `docker inspect`, are inherited by
child processes and often end up in logs. Docker secrets are mounted as files
under `/run/secrets/` only in the containers that list them and never appear
in `docker inspect`. This project keeps non-sensitive settings (domain, user
names, database name) in `srcs/.env` and all four passwords in Docker secrets.
The entrypoint scripts read the passwords from `/run/secrets/<name>` and no
password is written into a Dockerfile.

### Docker Network vs Host Network

With `network: host` a container uses the host's network stack directly. Every
port it opens is opened on the host and nothing is isolated. A user-defined
bridge network (`inception` here) gives the containers a private network with
built-in DNS, so they find each other by service name (`mariadb`,
`wordpress`). Only the ports listed under `ports:` are reachable from outside.
Here only nginx publishes a port (443). MariaDB (3306) and php-fpm (9000) can be
reached only from inside the network.

### Docker Volumes vs Bind Mounts

A bind mount maps any host path straight into a container. It is simple, but
it depends on the host's folder layout and permissions, and Docker does not
manage it. A named volume is created and tracked by Docker (`docker volume
ls`, `docker volume rm`), can be shared between services by name, and is
removed with `docker compose down -v`. The subject requires the data to live
in `/home/<login>/data`. This project therefore uses **named volumes**
(`db_data`, `wp_data`) with the `local` driver and `o: bind` options that point
them to `${DATA_DIR}/mariadb` and `${DATA_DIR}/wordpress`. Docker manages them
as volumes and the data stays in the folder the subject asks for.

## Instructions

### Prerequisites

- A Linux machine or VM with Docker Engine and the Docker Compose plugin
  (`docker compose`)
- `make`, plus `sudo` rights (`make fclean` deletes the data folder)

### Configuration

1. Make sure the four password files exist in `secrets/`. Each file holds a
   single password.
2. Check `srcs/.env`. `DOMAIN_NAME` (`<login>.42.fr`) and `DATA_DIR`
   (`/home/<login>/data`) come from `$USER` automatically. `HTTPS_PORT` sets
   the port nginx listens on.
3. Point the domain to your machine:

   ```sh
   echo "127.0.0.1 $USER.42.fr" | sudo tee -a /etc/hosts
   ```

### Running

| Command       | What it does                                                          |
|---------------|-----------------------------------------------------------------------|
| `make`        | Creates the data folders, builds the images and starts the stack     |
| `make build`  | Builds the images without starting them                               |
| `make down`   | Stops and removes the containers and the network. Data is kept       |
| `make clean`  | Same as `down`, and also removes the project images                   |
| `make fclean` | Same as `clean`, and also removes the volumes and `/home/<login>/data` |
| `make re`     | `fclean`, then rebuild and start from scratch                         |

Once the stack is up, open `https://<login>.42.fr` (add `:<HTTPS_PORT>` if it
is not 443). The browser will warn about the self-signed certificate, which is
expected. The admin panel is at `/wp-admin`.

Useful checks:

```sh
docker compose -f srcs/docker-compose.yml ps        # all three should be "Up"
docker compose -f srcs/docker-compose.yml logs -f   # follow the setup logs
openssl s_client -connect $USER.42.fr:443 -tls1_2 </dev/null  # TLS check
```

## Resources

- [Docker containers – How to Think About It by Eduardo Gonzalo](https://dev.to/educhigon/docker-containers-how-to-think-about-it-inception-42-exercise-4op9)
- [InceptionVm-guide by Bakr-1](https://github.com/Bakr-1/inceptionVm-guide)
- [Docker documentation](https://docs.docker.com/), especially
  [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Manage sensitive data with Docker secrets](https://docs.docker.com/engine/swarm/secrets/)
  and [secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker networking: bridge networks](https://docs.docker.com/engine/network/drivers/bridge/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/) and
  [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/)
- [NGINX documentation](https://nginx.org/en/docs/) and the
  [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [Alpine Linux packages](https://pkgs.alpinelinux.org/packages)
- Yelp Engineering, [Introducing dumb-init](https://engineeringblog.yelp.com/2016/01/dumb-init-an-init-for-docker.html),
  on why PID 1 matters in containers

### Use of AI

First instance of this project was created without AI help, only online
documentation and other peoples examples and guides were used. Then an AI
assistant (Claude Code) was used in multiple ways to assist:

- **Explanations:** providing answeres for question posed by the subject
  such as meaning of having secrets files instead of environment variables,
  how named volumes with bind options work, which ports are reachable from
  outside of the network.
- **Review:** checking the configuration against the subject's rules (no
  forbidden patterns, no passwords in Dockerfiles, no hardcoded login) and
  troubleshooting errors during execution.
- **Documentation:** providing first draft of documentation: this README,
  USER_DOC and DEV_DOC. The content was then reviewed manually.
