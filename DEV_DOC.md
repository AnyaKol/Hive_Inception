# Developer documentation

How to set up, build, run and maintain the Inception stack. For a project
overview and the design choices, see [README.md](README.md). For day-to-day
use, see [USER_DOC.md](USER_DOC.md).

## 1. Setting up the environment from scratch

### Prerequisites

- A Linux machine or VM
- Docker Engine and the Docker Compose plugin. Check with `docker compose version`
- `make` and `sudo`
- Your user can run Docker (`sudo usermod -aG docker $USER`, then log in again)
- Port 443 free on the host

### Configuration files

```
secrets/                     ← passwords, one per file, no trailing text
├── db_root_password.txt     MariaDB root
├── db_password.txt          MariaDB user used by WordPress
├── wp_admin_password.txt    WordPress administrator
└── wp_user_password.txt     WordPress second user (editor)
srcs/.env                    ← non-secret settings
```

**Secrets.** If the files are missing, create them:

```sh
mkdir -p secrets
for f in db_root_password db_password wp_admin_password wp_user_password; do
    openssl rand -base64 18 > secrets/$f.txt
done
chmod 600 secrets/*.txt
```

Keep `secrets/` out of git before the project is published.

**`srcs/.env`.** The variables:

| Variable          | Meaning                                                       |
|-------------------|---------------------------------------------------------------|
| `DOMAIN_NAME`     | `${USER}.42.fr`. Used for the certificate, the nginx `server_name` and the WordPress URL |
| `DATA_DIR`        | `/home/${USER}/data`. Where the volumes store data on the host |
| `MYSQL_DATABASE`  | Name of the WordPress database                                |
| `MYSQL_USER`      | Database user WordPress connects as                           |
| `WP_TITLE`        | Site title                                                    |
| `WP_ADMIN_USER`   | Administrator login. Must not contain "admin"/"administrator" |
| `WP_ADMIN_EMAIL`, `WP_USER`, `WP_USER_EMAIL` | Admin email, second user's login and email |
| `HTTPS_PORT`      | Port nginx listens on and publishes. Must be `443`            |

`DOMAIN_NAME` and `DATA_DIR` come from `$USER`, so the same files work for any
login. Don't hardcode a login. The Makefile does `include srcs/.env` to get
`DATA_DIR`.

**Hosts file.** Point the domain to the local machine:

```sh
echo "127.0.0.1 $USER.42.fr" | sudo tee -a /etc/hosts
```

## 2. Building and launching

```sh
make          # = make up
```

`make up` creates `$(DATA_DIR)/mariadb` and `$(DATA_DIR)/wordpress` if they're
missing, then runs `docker compose -f srcs/docker-compose.yml up --build -d`.

| Target   | Runs                                                       |
|----------|------------------------------------------------------------|
| `all`    | `up`                                                       |
| `build`  | creates the data folders, then `docker compose build`      |
| `up`     | creates the data folders, then `docker compose up --build -d` |
| `down`   | `docker compose down`. Removes containers and the network  |
| `clean`  | `docker compose down --rmi all`. Also removes the images   |
| `fclean` | `clean`, then `down -v`, then `sudo rm -rf $(DATA_DIR)`    |
| `re`     | `fclean all`                                               |

### What happens on first start

1. **mariadb** sees that `/var/lib/mysql/mysql` is missing. It runs
   `mariadb-install-db`, starts a temporary server with networking off, sets
   the root password, creates the database and user, shuts the temporary
   server down, and then `exec`s `mariadbd`.
2. **wordpress** waits until it can log in to MariaDB. It copies the WordPress
   sources into the volume, writes `wp-config.php`, runs `wp core install`
   (administrator) and `wp user create` (editor), and sets `home`/`siteurl`
   from `DOMAIN_NAME` and `HTTPS_PORT`. Then it `exec`s `php-fpm83 -F`.
3. **nginx** builds `nginx.conf` from its template with `envsubst`, generates
   a self-signed certificate, checks the config with `nginx -t`, and then
   `exec`s `nginx -g "daemon off;"`.

Each step is skipped if it has already been done, so restarts keep the data.
`depends_on` only sets the start order. The real wait for the database is the
loop in `wordpress_setup.sh`.

### Rebuilding after a change

| Changed                         | Do                                                      |
|---------------------------------|---------------------------------------------------------|
| A Dockerfile, `conf/` or `tools/` file | `make` (rebuilds the changed images and recreates their containers) |
| `srcs/.env` values for nginx    | `make`                                                   |
| Database or WordPress settings, users, passwords | `make re`. Setup runs only on an empty volume |
| One service only                | `docker compose -f srcs/docker-compose.yml up -d --build <service>` |

## 3. Managing containers and volumes

Set an alias to keep the commands short:

```sh
alias dc='docker compose -f srcs/docker-compose.yml'
```

| Task                         | Command                                     |
|------------------------------|---------------------------------------------|
| Status of the services       | `dc ps`                                     |
| Follow logs                  | `dc logs -f [service]`                      |
| Shell inside a container     | `dc exec <service> sh`                      |
| Restart one service          | `dc restart <service>`                      |
| List images                  | `docker images` (`nginx:inception`, `wordpress:inception`, `mariadb:inception`) |
| List / inspect volumes       | `docker volume ls`, `docker volume inspect srcs_db_data` |
| List / inspect the network   | `docker network ls`, `docker network inspect srcs_inception` |

Volume and network names get the Compose project name as a prefix. The project
name is the folder of the compose file (`srcs`), hence `srcs_db_data`.

TLS check (from the host):

```sh
dc exec mariadb sh -c 'mariadb -u root -p"$(cat /run/secrets/db_root_password)" -e "SHOW DATABASES; SELECT user,host FROM mysql.user;"'
dc exec wordpress wp user list --path=/var/www/html
dc exec nginx nginx -T | grep ssl_protocols
openssl s_client -connect $USER.42.fr:443 -tls1_1 -cipher 'DEFAULT:@SECLEVEL=0' </dev/null   # must fail
openssl s_client -connect $USER.42.fr:443 -tls1_2 </dev/null   # must succeed
openssl s_client -connect $USER.42.fr:443 -tls1_3 </dev/null   # must succeed
```

Nginx uses TLSv1.2 and TLSv1.3 ssl protocols. The TLSv1.1 is an older version
that browsers no longer accept. It is can also be rejected by OS before
reaching nginx, that is why parameter `-cipher 'DEFAULT:@SECLEVEL=0'` is added
to turns that client-side limit off and demonstrate rejection by nginx.

## 4. Where data is stored and how it persists

| Volume    | Mounted in  | Host folder       | Contents     |
|-----------|--------------|----------------|---------------|
| `db_data` | `mariadb:/var/lib/mysql`   | `$(DATA_DIR)/mariadb` | MariaDB data files |
| `wp_data` | `wordpress:/var/www/html`, `nginx:/var/www/html` | `$(DATA_DIR)/wordpress` | WordPress core, `wp-config.php`, themes, plugins, uploads |

Both are named volumes with the `local` driver and the options
`type: none, o: bind, device: ...`. Docker manages them as volumes, but the
files live in `/home/<login>/data` as the subject requires. The folders must
exist before `up` and the Makefile creates them.

How long things last:

- `make down`, container crashes, `restart: always` restarts and image
  rebuilds **keep** the data, because it lives on the host.
- `make fclean` and `make re` **delete** the data: the volumes are removed and
  `$(DATA_DIR)` is deleted with `sudo`.
- Secrets are not stored in a volume. Compose mounts them read-only at
  `/run/secrets/<name>` each time a container starts.
- The TLS certificate lives in the nginx container's own filesystem
  (`/etc/nginx/ssl`). It is created again whenever the nginx container is
  recreated.

Files in `$(DATA_DIR)` belong to container users (`mysql`, `www-data`), so
the host needs `sudo` to remove them. That's why `fclean` uses `sudo rm -rf`.
