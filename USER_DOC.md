# User documentation

This guide is for anyone who needs to run the Inception stack or manage its
website. It doesn't assume you know Docker.

## What the stack provides

| Service       | What it does   | Reachable from          |
|---------------|------------------------------------------------------------------------------|-------------------------|
| **nginx**     | Web server and the only entry point. Serves the site over HTTPS (TLS 1.2/1.3) | `https://<login>.42.fr` (port 443) |
| **WordPress** | The website and its admin panel, run by PHP-FPM | Only through nginx |
| **MariaDB**   | The database that stores posts, pages, users and settings | Only from WordPress |

You only ever talk to nginx. WordPress and MariaDB can't be reached from
outside the stack.

## Starting and stopping

Run every command from the root of the repository.

| Action                                       | Command       |
|----------------------------------------------|---------------|
| Start the stack (builds it the first time)   | `make`        |
| Stop the stack and keep all data             | `make down`   |
| Stop the stack and remove its images         | `make clean`  |
| **Delete everything, including site data**   | `make fclean` |
| Start over from an empty site                | `make re`     |

The first start takes a minute or two, while WordPress is installed. Later
starts are quick and your posts, users and settings are kept.

> ⚠️ `make fclean` and `make re` permanently delete the database and the
> website files in `/home/<login>/data`. They ask for your `sudo` password.

## Accessing the website

1. The domain `<login>.42.fr` must point to your machine. If the site doesn't
   open, add it to your computer's known hosts:

   ```sh
   echo "127.0.0.1 $USER.42.fr" | sudo tee -a /etc/hosts
   ```

2. Open **https://\<login\>.42.fr** in a browser.
3. The browser will say the connection is not private. That's expected,
   because the certificate is self-signed. Choose "Advanced" and then
   "Proceed".

### Administration panel

Open **https://\<login\>.42.fr/wp-admin** and log in with one of the accounts
below.

## Credentials

| Account                | User name                         | Password file                  |
|------------------------|-----------------------------------|--------------------------------|
| WordPress administrator | `WP_ADMIN_USER` in `srcs/.env` (`chief`) | `secrets/wp_admin_password.txt` |
| WordPress editor       | `WP_USER` in `srcs/.env` (`editor`) | `secrets/wp_user_password.txt`  |
| Database user          | `MYSQL_USER` in `srcs/.env` (`wp_user`) | `secrets/db_password.txt`       |
| Database root          | `root`                            | `secrets/db_root_password.txt`  |

- User names, emails and other non-secret settings are in `srcs/.env`.
- Each password is the only line in its file in `secrets/`.
- Passwords are applied **only when the site is first installed**. Editing a
  file later does not change an existing password. To change one, either:
  - change it in WordPress (Users → Profile), or
  - edit the file and run `make re` to reinstall from scratch (this **erases
    all site data**).

Never share the `secrets/` folder or commit it to a public repository.

## Checking that everything works

1. **Containers are running:**

   ```sh
   docker compose -f srcs/docker-compose.yml ps
   ```

   You should see `nginx`, `wordpress` and `mariadb`, all with status `Up`. If
   one shows `Restarting`, it is crashing. Look at its logs.

2. **Logs:**

   ```sh
   docker compose -f srcs/docker-compose.yml logs wordpress   # or nginx, mariadb
   ```

   Healthy logs end with `Starting PHP-FPM...` (wordpress), `Starting Nginx...`
   (nginx) and `Starting MariaDB...` (mariadb).

3. **The site answers over HTTPS:**

   ```sh
   curl -kI https://$USER.42.fr
   ```

   The first line of the answer should be `HTTP/2 200` (or a `30x` redirect).

4. **Plain HTTP is refused:** `curl -I http://$USER.42.fr` should fail,
   because only port 443 is open.
